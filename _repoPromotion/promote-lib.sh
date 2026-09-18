#!/usr/bin/env bash
# Shared library for branch-promotion scripts. Sourced, not run directly.
#
# Behavior: for each repo listed in repos.env, opens a PR promoting one branch
# into another (e.g. 'dev' → 'qa'). It only opens PRs; it never merges them.
# Existing open PRs for the same branch pair are detected and left alone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_ENV="${SCRIPT_DIR}/repos.env"

# All repos live in this GitHub organization.
GH_ORG="pankosmia"

# ---- toggles -------------------------------------------------------------
# DRY_RUN is normally set via the --dry-run flag. See run_promotion(). It is
# also readable from the environment, but you do not need to set it manually;
# The flag is the intended interface.
DRY_RUN="${DRY_RUN:-0}"

# ---- colors (only if stdout is a tty) ------------------------------------
if [[ -t 1 ]]; then
  C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'
  C_BLU=$'\e[34m'; C_DIM=$'\e[2m'; C_RST=$'\e[0m'
else
  C_RED=; C_GRN=; C_YEL=; C_BLU=; C_DIM=; C_RST=
fi

# ---- summary accumulators ------------------------------------------------
declare -a SUM_CREATED=() SUM_EXISTING=() SUM_NOCHANGE=() \
           SUM_WARN=() SUM_SKIP=() SUM_ERROR=()

preflight() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "${C_RED}error:${C_RST} GitHub CLI (gh) is not installed." >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "${C_RED}error:${C_RST} gh is not authenticated. Run: gh auth login" >&2
    exit 1
  fi
  if [[ ! -f "$REPOS_ENV" ]]; then
    echo "${C_RED}error:${C_RST} repos.env not found at $REPOS_ENV" >&2
    exit 1
  fi
}

# Read repos.env: one bare repo name per line. Each is qualified with $GH_ORG.
# Blank lines and # comments are ignored.
read_repos() {
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      "$REPOS_ENV" | grep -v '^$' | while IFS= read -r line; do
    printf '%s/%s\n' "$GH_ORG" "$line"
  done
}

# Does a branch exist on the remote repo?
branch_exists() {
  local repo="$1" branch="$2"
  gh api "repos/${repo}/branches/${branch}" >/dev/null 2>&1
}

# Return an existing OPEN PR url for base<-head, or empty string.
existing_pr_url() {
  local repo="$1" base="$2" head="$3"
  gh pr list --repo "$repo" --state open \
    --base "$base" --head "$head" \
    --json url --jq '.[0].url // empty' 2>/dev/null
}

# Compare: prints status ("ahead"|"behind"|"identical"|"diverged")
# for head relative to base (i.e. base...head).
compare_status() {
  local repo="$1" base="$2" head="$3"
  gh api "repos/${repo}/compare/${base}...${head}" \
    --jq '.status' 2>/dev/null
}

# Create a PR with one automatic retry if we hit a secondary rate limit.
# Echoes the PR url on success; returns non-zero on failure.
create_pr_with_retry() {
  local repo="$1" base="$2" head="$3" title="$4" body="$5"
  local attempt out rc

  for attempt in 1 2; do
    if out="$(gh pr create \
          --repo "$repo" \
          --base "$base" \
          --head "$head" \
          --title "$title" \
          --body "$body" 2>&1)"; then
      printf '%s\n' "$out"
      return 0
    fi
    rc=$?

    # Detect secondary/abuse rate-limit signals in the error text.
    if grep -qiE 'secondary rate limit|abuse detection|rate limit' <<<"$out"; then
      local wait=60
      echo "  ${C_YEL}rate limited on ${repo}; waiting ${wait}s before one retry...${C_RST}" >&2
      sleep "$wait"
      continue
    fi

    # Any other error: don't retry.
    printf '%s\n' "$out" >&2
    return "$rc"
  done

  # Second attempt also failed.
  printf '%s\n' "$out" >&2
  return 1
}

# Core routine. Promotes head -> base for a single repo (opens a PR only).
promote_one() {
  local repo="$1" base="$2" head="$3" title="$4" body="$5"

  # 1. both branches must exist
  if ! branch_exists "$repo" "$head"; then
    SUM_SKIP+=("$repo — missing head branch '$head'")
    echo "${C_DIM}skip:${C_RST} $repo (no '$head' branch)"
    return 0
  fi
  if ! branch_exists "$repo" "$base"; then
    SUM_SKIP+=("$repo — missing base branch '$base'")
    echo "${C_DIM}skip:${C_RST} $repo (no '$base' branch)"
    return 0
  fi

  # 2. direction / changes check (head relative to base)
  local status
  status="$(compare_status "$repo" "$base" "$head")" || {
    SUM_ERROR+=("$repo — compare API failed")
    echo "${C_RED}error:${C_RST} $repo (compare failed)"
    return 1
  }

  case "$status" in
    identical)
      SUM_NOCHANGE+=("$repo")
      echo "${C_DIM}ok:${C_RST} $repo — $base already up to date with $head"
      return 0
      ;;
    behind)
      # head is behind base => base is AHEAD of head (unintended)
      SUM_WARN+=("$repo — '$base' is AHEAD of '$head' (unexpected)")
      echo "${C_YEL}warn:${C_RST} $repo — '$base' is ahead of '$head'; skipping"
      return 0
      ;;
    diverged)
      SUM_WARN+=("$repo — '$head' and '$base' have DIVERGED")
      echo "${C_YEL}warn:${C_RST} $repo — '$head' and '$base' diverged; skipping"
      return 0
      ;;
    ahead)
      : # normal case, proceed
      ;;
    *)
      SUM_ERROR+=("$repo — unknown compare status '$status'")
      echo "${C_RED}error:${C_RST} $repo (unknown status '$status')"
      return 1
      ;;
  esac

  # 3. avoid duplicate PRs
  local pr_url
  pr_url="$(existing_pr_url "$repo" "$base" "$head")"
  if [[ -n "$pr_url" ]]; then
    SUM_EXISTING+=("$repo — $pr_url")
    echo "${C_BLU}exists:${C_RST} $repo — open PR $pr_url"
    return 0
  fi

  # 4. create PR
  if [[ "$DRY_RUN" == "1" ]]; then
    SUM_CREATED+=("$repo — (dry-run) would open $head -> $base")
    echo "${C_GRN}dry-run:${C_RST} $repo — would open PR $head -> $base"
    return 0
  fi

  if ! pr_url="$(create_pr_with_retry "$repo" "$base" "$head" "$title" "$body")"; then
    SUM_ERROR+=("$repo — pr create failed: $pr_url")
    echo "${C_RED}error:${C_RST} $repo — pr create failed:" >&2
    echo "  $pr_url" >&2
    return 1
  fi

  SUM_CREATED+=("$repo — $pr_url")
  echo "${C_GRN}created:${C_RST} $repo — $pr_url"

  return 0
}

print_summary() {
  local from="$1" to="$2"
  echo
  echo "==================== SUMMARY ($from -> $to) ===================="
  _dump() { local label="$1" col="$2"; shift 2
    (( $# )) || return 0
    echo "${col}${label} (${#}):${C_RST}"
    printf '  - %s\n' "$@"
  }
  local created_label="Created"
  (( DRY_RUN )) && created_label="Would Create"

  local skipped_label="Skipped"
  (( DRY_RUN )) && skipped_label="Would Skip"

  _dump "$created_label"  "$C_GRN" "${SUM_CREATED[@]}"
  _dump "Existing PRs"    "$C_BLU" "${SUM_EXISTING[@]}"
  _dump "No changes"      "$C_DIM" "${SUM_NOCHANGE[@]}"
  _dump "Warnings"        "$C_YEL" "${SUM_WARN[@]}"
  _dump "$skipped_label" "$C_DIM" "${SUM_SKIP[@]}"
  _dump "Errors"          "$C_RED" "${SUM_ERROR[@]}"
  echo "==============================================================="
}

run_promotion() {
  # Parse flags first, then positional args.
  local -a positional=()
  for arg in "$@"; do
    case "$arg" in
      --dry-run) export DRY_RUN=1 ;;
      --*) echo "unknown option: $arg" >&2; exit 1 ;;
      *) positional+=("$arg") ;;
    esac
  done

  local base="${positional[0]}" head="${positional[1]}"
  local title="${positional[2]}" body="${positional[3]}"
  preflight

  local had_error=0
  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    promote_one "$repo" "$base" "$head" "$title" "$body" || had_error=1
  done < <(read_repos)

  print_summary "$head" "$base"
  # exit 2 if any hard errors occurred (warnings/skips are fine)
  (( ${#SUM_ERROR[@]} )) && return 2
  return 0
}

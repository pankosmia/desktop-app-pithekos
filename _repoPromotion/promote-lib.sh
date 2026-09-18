#!/usr/bin/env bash
# Shared library for branch-promotion scripts. Sourced, not run directly.
#
# Behavior: for each repo listed in repos.env, opens a PR promoting one branch
# into another (e.g. 'dev' -> 'qa'). It only opens PRs; it never merges them.
# Existing open PRs for the same branch pair are detected and left alone.
#
# A straight promotion (base has nothing head lacks) is the normal, expected
# case: a clean PR is opened. When BASE has commits that HEAD does not, the PR
# body additionally flags that fact, listing those base-only commits as
# clickable links for the PR reviewer's information.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_ENV="${SCRIPT_DIR}/repos.env"

# All repos live in this GitHub organization.
GH_ORG="pankosmia"

# ---- toggles -------------------------------------------------------------
# DRY_RUN is normally set via the --dry-run flag. See run_promotion(). It is
# also readable from the environment, but you do not need to set it manually;
# the flag is the intended interface.
DRY_RUN="${DRY_RUN:-0}"

# ---- colors (only if stdout is a tty) ------------------------------------
if [[ -t 1 ]]; then
  C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'
  C_BLU=$'\e[34m'; C_DIM=$'\e[2m'; C_RST=$'\e[0m'
  C_MAG=$'\e[35m'
else
  C_RED=; C_GRN=; C_YEL=; C_BLU=; C_DIM=; C_RST=; C_MAG=
fi

# ---- summary accumulators ------------------------------------------------
# SUM_FLAGGED: PRs opened where base has commits head doesn't; Will list them in PR description.
declare -a SUM_CREATED=() SUM_FLAGGED=() SUM_EXISTING=() SUM_NOCHANGE=() \
           SUM_WARN=() SUM_SKIP=() SUM_ERROR=()

preflight() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "${C_RED}error:${C_RST} GitHub CLI (gh) is not installed." >&2
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "${C_RED}error:${C_RST} jq is not installed." >&2
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

# Return the FULL compare JSON for head relative to base (base...head).
# Echoes JSON on success; returns non-zero on failure.
compare_full() {
  local repo="$1" base="$2" head="$3"
  gh api "repos/${repo}/compare/${base}...${head}" 2>/dev/null
}

# Extract just the status ("ahead"|"behind"|"identical"|"diverged")
# from a compare JSON blob passed on stdin.
compare_status_from_json() {
  jq -r '.status' 2>/dev/null
}

# Build the FLAGGED section of a PR body: only used when base has commits that
# head does not. Lists any base-only commits as clickable links.
#
# $1 = repo slug "org/name"
# $2 = head branch name (e.g. "dev")
# $3 = base branch name (e.g. "qa")
# $4 = compare JSON for head...base (base's extra commits)
# Echoes Markdown on stdout.
build_flagged_body() {
  local repo="$1" head="$2" base="$3" behind_json="$4"

  local base_commits
  base_commits="$(jq -r --arg repo "$repo" '
    .commits[]?
    | "- [`\(.sha[0:7])`](https://github.com/\($repo)/commit/\(.sha)) \(.commit.message | split("\n")[0])"
  ' <<<"$behind_json")"

  printf '### Commits on `%s` not in `%s`\n' "$base" "$head"
  if [[ -z "$base_commits" ]]; then
    printf '_None found (unexpected — behind_by was > 0; check compare directly)._\n\n'
  else
    printf '%s\n\n' "$base_commits"
  fi
}

# Create a PR with one automatic retry if we hit a secondary rate limit.
# Echoes the PR url on success; returns non-zero on failure.
# Warnings (e.g. "uncommitted changes") are routed to stderr so callers only
# capture the URL on stdout.
create_pr_with_retry() {
  local repo="$1" base="$2" head="$3" title="$4" body="$5"
  local attempt out rc
  for attempt in 1 2; do
    if out="$(gh pr create \
                --repo "$repo" \
                --base "$base" \
                --head "$head" \
                --title "$title" \
                --body "$body" 2>/dev/null)"; then
      # Keep only the PR URL line, in case anything else leaks to stdout.
      grep -Eo 'https://github\.com/[^[:space:]]+/pull/[0-9]+' <<<"$out" | tail -n1
      return 0
    fi
    rc=$?
    # gh's own diagnostics go to stderr; grab them for rate-limit detection.
    out="$(gh pr create \
             --repo "$repo" \
             --base "$base" \
             --head "$head" \
             --title "$title" \
             --body "$body" 2>&1 1>/dev/null || true)"
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
  printf '%s\n' "$out" >&2
  return 1
}

# Core routine. Promotes head -> base for a single repo (opens a PR only).
# The decision to FLAG is based purely on behind_by > 0 (base has commits
# head lacks).
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
  local ahead_json status
  ahead_json="$(compare_full "$repo" "$base" "$head")" || {
    SUM_ERROR+=("$repo — compare API failed")
    echo "${C_RED}error:${C_RST} $repo (compare failed)"
    return 1
  }
  status="$(compare_status_from_json <<<"$ahead_json")" || status=""

  case "$status" in
    identical)
      SUM_NOCHANGE+=("$repo")
      echo "${C_DIM}ok:${C_RST} $repo — $base already up to date with $head"
      return 0
      ;;
    behind)
      # head is behind base => base is AHEAD of head, and head has NOTHING new.
      # Nothing to promote.
      SUM_WARN+=("$repo — '$base' is AHEAD of '$head' (nothing to promote)")
      echo "${C_YEL}warn:${C_RST} $repo — '$base' is ahead of '$head'; nothing to promote"
      return 0
      ;;
    ahead|diverged)
      : # something to promote; proceed below. 'diverged' is not special.
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

  # 4. determine whether base has commits head lacks (the only thing we flag).
  local behind_by flagged=0 final_body="$body"
  behind_by="$(jq -r '.behind_by // 0' <<<"$ahead_json")"
  if [[ "${behind_by:-0}" -gt 0 ]]; then
    flagged=1
    # Reverse compare needed only here, to enumerate base's extra files.
    local behind_json flagged_section
    behind_json="$(compare_full "$repo" "$head" "$base")" || {
      SUM_ERROR+=("$repo — reverse compare API failed")
      echo "${C_RED}error:${C_RST} $repo (reverse compare failed)"
      return 1
    }
    flagged_section="$(build_flagged_body "$repo" "$head" "$base" "$behind_json")"
    final_body="${body}

---

${flagged_section}"
# IMPORTANT: Keep `---` and `${flagged_section}"` left justified just above.
# They are markdown.
  fi

  # 5. create PR (respecting --dry-run). Title is identical in all cases.
  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$flagged" == "1" ]]; then
      SUM_FLAGGED+=("$repo — (dry-run) would open $head -> $base ('$base' has commits not in '$head')")
      echo "${C_MAG}dry-run:${C_RST} $repo — would open PR $head -> $base (flagged: '$base' has extra commits)"
    else
      SUM_CREATED+=("$repo — (dry-run) would open $head -> $base")
      echo "${C_GRN}dry-run:${C_RST} $repo — would open PR $head -> $base"
    fi
    return 0
  fi

  if ! pr_url="$(create_pr_with_retry "$repo" "$base" "$head" "$title" "$final_body")"; then
    SUM_ERROR+=("$repo — pr create failed: $pr_url")
    echo "${C_RED}error:${C_RST} $repo — pr create failed:" >&2
    echo "  $pr_url" >&2
    return 1
  fi

  if [[ -z "$pr_url" ]]; then
    SUM_ERROR+=("$repo — PR created but URL not parseable")
    echo "${C_RED}error:${C_RST} $repo — could not parse PR URL from output" >&2
    return 1
  fi

  if [[ "$flagged" == "1" ]]; then
    SUM_FLAGGED+=("$repo — $pr_url ('$base' has commits not in '$head')")
    echo "${C_MAG}created (flagged):${C_RST} $repo — $pr_url"
  else
    SUM_CREATED+=("$repo — $pr_url")
    echo "${C_GRN}created:${C_RST} $repo — $pr_url"
  fi
  return 0
}

print_summary() {
  local from="$1" to="$2"
  echo
  echo "==================== SUMMARY ($from -> $to) ===================="
  _dump() {
    local label="$1" col="$2"; shift 2
    (( $# )) || return 0
    echo "${col}${label} (${#}):${C_RST}"
    printf '  - %s\n' "$@"
  }

  local created_label="Created"
  (( DRY_RUN )) && created_label="Would Create"
  local flagged_label="Created (base has commits not in head; Listed in PR description"
  (( DRY_RUN )) && flagged_label="Would Create (base has commits not in head; Would be listed in PR description)"
  local skipped_label="Skipped"
  (( DRY_RUN )) && skipped_label="Would Skip"

  _dump "$created_label"  "$C_GRN" "${SUM_CREATED[@]}"
  _dump "$flagged_label"  "$C_MAG" "${SUM_FLAGGED[@]}"
  _dump "Existing PRs"    "$C_BLU" "${SUM_EXISTING[@]}"
  _dump "No changes"      "$C_DIM" "${SUM_NOCHANGE[@]}"
  _dump "Warnings"        "$C_YEL" "${SUM_WARN[@]}"
  _dump "$skipped_label"  "$C_DIM" "${SUM_SKIP[@]}"
  _dump "Errors"          "$C_RED" "${SUM_ERROR[@]}"
  echo "==============================================================="
}

run_promotion() {
  # Parse flags first, then positional args.
  local -a positional=()
  for arg in "$@"; do
    case "$arg" in
      --dry-run) export DRY_RUN=1 ;;
      --*)       echo "unknown option: $arg" >&2; exit 1 ;;
      *)         positional+=("$arg") ;;
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
  return "$had_error"
}

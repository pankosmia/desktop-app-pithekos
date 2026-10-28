#!/usr/bin/env bash
# Open one draft PR per pankosmia repo listed in repo.env to update a module.
#
# Usage: ./update-module.sh [--q] [--env FILE] [--reviewer LOGIN[,LOGIN]] <module@version>
#   --q                 quiet: hide command output (default is verbose)
#   --env FILE          repo list (default: repo.env next to this script)
#   --reviewer LOGIN    GitHub user(s) requested as reviewer on each PR
#
# repo.env: repo names (or pankosmia/<name>) separated by newlines, spaces or
# commas. '#' comments and a leading "KEY=" are ignored.
#
# For each repo: clone dev, branch "<module@version>_<dateTime>", pnpm add,
# pre_commit script (or build), commit, push, draft PR targeting dev.
# PRs are never merged. One journal line per repo is printed on stdout.

set -u -o pipefail

ORG="pankosmia"
BASE_BRANCH="dev"
QUIET=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/repo.env"
REVIEWER=""

usage() {
  sed -n '2,/^$/{/^$/!p;}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

SPEC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --q) QUIET=1 ;;
    --env)
      [ $# -ge 2 ] || usage
      ENV_FILE="$2"
      shift
      ;;
    --reviewer)
      [ $# -ge 2 ] || usage
      REVIEWER="$2"
      shift
      ;;
    -h | --help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) [ -z "$SPEC" ] || usage; SPEC="$1" ;;
  esac
  shift
done
[ -n "$SPEC" ] || usage

# Split on the last '@' so scoped modules (@scope/name@1.2.3) work.
MODULE="${SPEC%@*}"
VERSION="${SPEC##*@}"
if [ -z "$MODULE" ] || [ "$MODULE" = "$SPEC" ] || [ -z "$VERSION" ]; then
  echo "Invalid argument '$SPEC': expected module@version" >&2
  exit 2
fi

BRANCH="${MODULE}@${VERSION}_$(date +%Y%m%dT%H%M%S)"
if ! git check-ref-format --branch "$BRANCH" > /dev/null 2>&1; then
  echo "'$BRANCH' is not a valid git branch name (ranges like ^ or ~ are not allowed in the version)" >&2
  exit 2
fi

for tool in git gh pnpm node; do
  command -v "$tool" > /dev/null 2>&1 || { echo "Missing tool: $tool" >&2; exit 1; }
done
gh auth status > /dev/null 2>&1 || { echo "gh is not authenticated (run: gh auth login)" >&2; exit 1; }
[ -f "$ENV_FILE" ] || { echo "Repo list not found: $ENV_FILE" >&2; exit 1; }

START_DIR="$PWD"
WORK_DIR="$(mktemp -d)"
trap 'cd "$START_DIR"; rm -rf "$WORK_DIR"' EXIT

run() {
  if [ "$QUIET" -eq 1 ]; then
    "$@" > /dev/null 2>&1 < /dev/null
  else
    "$@" < /dev/null
  fi
}

journal() {
  printf '%s | %s | %s | %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" "$3"
}

read_repos() {
  sed -e 's/#.*//' -e 's/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=//' -e 's/["'"'"']//g' -e 's/,/ /g' "$ENV_FILE" |
    tr -s '[:space:]' '\n' |
    sed -e "s#^$ORG/##" -e '/^$/d'
}

# Prints every section of package.json holding $MODULE (one per line), or
# fails if there is none.
dependency_sections() {
  node -e '
    const pkg = require("./package.json");
    const keys = ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"];
    const found = keys.filter((key) => pkg[key] && pkg[key][process.argv[1]]);
    found.forEach((key) => console.log(key));
    process.exit(found.length ? 0 : 1);
  ' "$MODULE"
}

has_script() {
  node -e 'const s = require("./package.json").scripts || {}; process.exit(s[process.argv[1]] ? 0 : 1)' "$1"
}

# Returns 0 when the PR is open. Otherwise returns 1 with REASON set, and
# SKIP=1 when the repo was skipped on purpose rather than failing.
# On success REASON holds the PR URL.
process_repo() {
  local name="$1" dir="$WORK_DIR/$1" info archived permission sections after section flag check_script body template file
  local flags=()

  info="$(gh repo view "$ORG/$name" --json isArchived,viewerPermission --jq '[.isArchived, .viewerPermission] | @tsv' 2> /dev/null)" ||
    { REASON="repo not found or not readable"; SKIP=1; return 1; }
  IFS=$'\t' read -r archived permission <<< "$info"
  if [ "$archived" = "true" ]; then
    REASON="archived"; SKIP=1; return 1
  fi
  case "$permission" in
    WRITE | MAINTAIN | ADMIN) ;;
    *) REASON="no write access ($permission)"; SKIP=1; return 1 ;;
  esac

  run gh repo clone "$ORG/$name" "$dir" -- --branch "$BASE_BRANCH" --depth 1 ||
    { REASON="clone of '$BASE_BRANCH' failed (missing branch or access)"; SKIP=1; return 1; }
  cd "$dir" || { REASON="cannot enter clone"; return 1; }

  if git ls-remote --exit-code --heads origin "$BRANCH" > /dev/null 2>&1; then
    REASON="branch $BRANCH already exists"; SKIP=1; return 1
  fi
  [ -f package.json ] || { REASON="no package.json"; SKIP=1; return 1; }
  sections="$(dependency_sections)" ||
    { REASON="$MODULE is not a dependency"; SKIP=1; return 1; }

  # --save-peer also writes devDependencies, so it covers a dev entry too.
  # It runs first so that a plain add can restore a regular dependency.
  if grep -qx peerDependencies <<< "$sections"; then
    flags+=("--save-peer")
  fi
  if grep -qx dependencies <<< "$sections"; then
    flags+=("")
  elif grep -qx devDependencies <<< "$sections" && ! grep -qx peerDependencies <<< "$sections"; then
    flags+=("-D")
  fi
  if grep -qx optionalDependencies <<< "$sections"; then
    flags+=("-O")
  fi

  # Work happens on a new branch, never on the base branch.
  run git switch -c "$BRANCH" || { REASON="cannot create branch"; return 1; }

  for flag in "${flags[@]}"; do
    # shellcheck disable=SC2086 # $flag is empty or a single option
    run pnpm add $flag "$MODULE@$VERSION" || { REASON="pnpm add $flag failed"; return 1; }
  done

  # Every section that held the module must still hold it.
  after="$(dependency_sections)" || { REASON="$MODULE vanished from package.json"; return 1; }
  while read -r section; do
    grep -qx "$section" <<< "$after" ||
      { REASON="$MODULE was moved out of $section by pnpm add"; return 1; }
  done <<< "$sections"

  if has_script pre_commit; then
    check_script="pre_commit"
  elif has_script build; then
    check_script="build"
  else
    REASON="no pre_commit or build script"; return 1
  fi
  run pnpm run "$check_script" || { REASON="pnpm run $check_script failed"; return 1; }

  # Stage only manifest/lock files so build output is never committed.
  for file in package.json pnpm-lock.yaml pnpm-workspace.yaml; do
    if [ -f "$file" ]; then git add "$file"; fi
  done
  if git diff --cached --quiet; then
    REASON="no change ($MODULE already at $VERSION)"; SKIP=1; return 1
  fi
  run git commit -m "chore: update $MODULE to $VERSION" || { REASON="commit failed"; return 1; }
  run git push -u origin "$BRANCH" || { REASON="push failed"; return 1; }

  body="Update \`$MODULE\` to \`$VERSION\` with \`pnpm add $MODULE@$VERSION\`.

Checked with \`pnpm run $check_script\`. Base branch: \`$BASE_BRANCH\`."
  for template in .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md; do
    if [ -f "$template" ]; then
      body="$body

$(cat "$template")"
      break
    fi
  done

  local reviewer_args=()
  if [ -n "$REVIEWER" ]; then
    reviewer_args=(--reviewer "$REVIEWER")
  fi

  REASON="$(gh pr create --draft --base "$BASE_BRANCH" --head "$BRANCH" --title "$BRANCH" --body "$body" "${reviewer_args[@]+"${reviewer_args[@]}"}" < /dev/null 2>&1)" ||
    { REASON="PR creation failed: $(echo "$REASON" | tail -n 1)"; return 1; }
  REASON="$(echo "$REASON" | tail -n 1)"
  return 0
}

mapfile -t REPOS < <(read_repos)
[ "${#REPOS[@]}" -gt 0 ] || { echo "No repo found in $ENV_FILE" >&2; exit 1; }

FAILED=0
for repo in "${REPOS[@]}"; do
  REASON=""
  SKIP=0
  if process_repo "$repo"; then
    journal "$repo" "PR_CREATED" "$REASON"
  elif [ "$SKIP" -eq 1 ]; then
    journal "$repo" "SKIPPED" "$REASON"
  else
    FAILED=$((FAILED + 1))
    journal "$repo" "FAILED" "$REASON"
  fi
  cd "$START_DIR" || exit 1
  rm -rf "$WORK_DIR/$repo"
done

[ "$FAILED" -eq 0 ]

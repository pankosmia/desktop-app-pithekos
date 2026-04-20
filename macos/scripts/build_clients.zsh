#!/usr/bin/env zsh

# Run from: pankosmia/<repo-name>/linux/scripts

# Usage:
#   ./build_clients.zsh [branch] [fallback_tier] [-d] [-f]
#     The -d argument means to delete past logs without asking
#     The -f argument means only fresh clones are being built, so pulling is skipped.
#     The first non-flag argument is the branch name (default: main)
#     The second non-flag argument is the fallback tier: dev, qa, or main (default: same as branch)

# Examples:
#   ./build_clients.zsh                        # defaults to "main"
#   ./build_clients.zsh dev                    # tries dev → qa → main
#   ./build_clients.zsh my-branch dev         # tries my-branch → dev → qa → main
#   ./build_clients.zsh my-branch qa -d       # tries my-branch → qa → main, deletes past logs
#   ./build_clients.zsh -f -d dev              # fresh clone (skips pulling), delete logs, branch=dev → qa → main

source ../../app_config.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- parse args ---
deleteLogs="-no"
FRESH_CLONE=""
BRANCH=""
FALLBACK_TIER=""
while [ $# -gt 0 ]; do
  if [ "$1" = "-d" ]; then
    deleteLogs="-d"
  elif [ "$1" = "-f" ]; then
    FRESH_CLONE=1
  elif [ -z "$BRANCH" ]; then
    BRANCH="$1"
  elif [ -z "$FALLBACK_TIER" ]; then
    FALLBACK_TIER="$1"
  fi
  shift
done

# Default branch to main if not provided
if [ -z "$BRANCH" ]; then
  BRANCH="main"
fi

# If no fallback tier specified, derive from the branch itself
if [ -z "$FALLBACK_TIER" ]; then
  case "${BRANCH:l}" in
    dev) FALLBACK_TIER="dev" ;;
    qa)  FALLBACK_TIER="qa" ;;
    *)   FALLBACK_TIER="main" ;;
  esac
fi

# Normalize fallback tier: anything other than dev or qa becomes main
case "${FALLBACK_TIER:l}" in
  dev) FALLBACK_TIER="dev" ;;
  qa)  FALLBACK_TIER="qa" ;;
  *)   FALLBACK_TIER="main" ;;
esac

# --- delete past logs (prompt unless -d) ---
if ls "${SCRIPT_DIR}"/build_clients_*.log >/dev/null 2>&1; then
  echo
  if [ "$deleteLogs" = "-d" ]; then
    rm -f "${SCRIPT_DIR}"/build_clients_*.log
  else
    while true; do
      read -r "c?Delete past logs? [Y/n]: "
      if [ -z "$c" ] || [ "$c" = "Y" ] || [ "$c" = "y" ]; then
        rm -f "${SCRIPT_DIR}"/build_clients_*.log
        break
      elif [ "$c" = "N" ] || [ "$c" = "n" ]; then
        break
      else
        echo "\"$c\" is not a valid response. Type y or 'Enter' to delete past logs, or 'n' to keep them."
      fi
    done
  fi
fi

# --- logging + failure tracking ---
LOG="${SCRIPT_DIR}/build_clients_$(date +%Y%m%d_%H%M%S).log"
echo "===== Build started $(date) =====" > "$LOG"

FAILCOUNT=0
FAILS=()
SKIPCOUNT=0
SKIPS=()

log() {
  echo "$*"
  echo "$*" >> "$LOG"
}

run() {
  "$@" 2>&1 | tee -a "$LOG"
  return "${pipestatus[1]:-$?}"   # zsh: exit status of first command in pipeline
}

markfail() {
  FAILCOUNT=$((FAILCOUNT + 1))
  FAILS+=("[$1] $2 :: $3")
}

markskip() {
  SKIPCOUNT=$((SKIPCOUNT + 1))
  SKIPS+=("[$1] $2 ($3): $4")
}

# --- checkout with fallback logic ---
checkout_branch() {
  local cb_type="$1"
  local cb_repo="$2"
  local branch_lower="${BRANCH:l}"

  log "> git checkout $BRANCH..."
  if run git checkout "$BRANCH"; then
    CHECKED_OUT_BRANCH="$BRANCH"
    return
  fi

  # Branch didn't exist -- apply fallback based on FALLBACK_TIER
  if [ "$FALLBACK_TIER" = "dev" ]; then
    if [ "$branch_lower" != "dev" ]; then
      log "> Branch \"$BRANCH\" not found, trying \"dev\"..."
      if run git checkout dev; then
        CHECKED_OUT_BRANCH="dev"
        return
      fi
    fi

    log "> Branch \"dev\" not found, trying \"qa\"..."
    if run git checkout qa; then
      CHECKED_OUT_BRANCH="qa"
      return
    fi

    log "> Branch \"qa\" not found, falling back to \"main\"..."
    if ! run git checkout main; then
      markfail "$cb_type" "$cb_repo" "git checkout main (fallback from $BRANCH)"
    fi
    CHECKED_OUT_BRANCH="main"
    return
  fi

  if [ "$FALLBACK_TIER" = "qa" ]; then
    if [ "$branch_lower" != "qa" ]; then
      log "> Branch \"$BRANCH\" not found, trying \"qa\"..."
      if run git checkout qa; then
        CHECKED_OUT_BRANCH="qa"
        return
      fi
    fi

    log "> Branch \"qa\" not found, falling back to \"main\"..."
    if ! run git checkout main; then
      markfail "$cb_type" "$cb_repo" "git checkout main (fallback from $BRANCH)"
    fi
    CHECKED_OUT_BRANCH="main"
    return
  fi

  if [ "$branch_lower" = "qa" ]; then
    if [ "$branch_lower" != "qa" ]; then
      log "> Branch \"$BRANCH\" not found, trying \"qa\"..."
      if run git checkout qa; then
        CHECKED_OUT_BRANCH="qa"
        return
      fi
    fi

    log "> Branch \"qa\" not found, falling back to \"main\"..."
    if ! run git checkout main; then
      markfail "$cb_type" "$cb_repo" "git checkout main (fallback from $BRANCH)"
    fi
    CHECKED_OUT_BRANCH="main"
    return
  fi

  # FALLBACK_TIER is main -- fall back directly to main
  log "> Branch \"$BRANCH\" not found, falling back to \"main\"..."
  if ! run git checkout main; then
    markfail "$cb_type" "$cb_repo" "git checkout main (fallback from $BRANCH)"
  fi
  CHECKED_OUT_BRANCH="main"
}

# --- pull logic ---
safe_pull() {
  local sp_type="$1"
  local sp_repo="$2"

  if [ -n "$FRESH_CLONE" ]; then
    log "> Skipping pull -- -f flag set, 'fresh' clone, no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "-f flag set, 'fresh' clone, no pull"
    return
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    log "> Skipping pull -- uncommitted local changes detected on \"$CHECKED_OUT_BRANCH\", no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "uncommitted local changes, no pull"
    return
  fi

  if ! git rev-parse --verify "origin/$CHECKED_OUT_BRANCH" >/dev/null 2>&1; then
    log "> Skipping pull -- origin/$CHECKED_OUT_BRANCH does not exist, no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "origin/$CHECKED_OUT_BRANCH does not exist, no pull"
    return
  fi

  local local_ahead
  local_ahead=$(git rev-list "origin/$CHECKED_OUT_BRANCH..HEAD" --count 2>/dev/null)
  if [ "$local_ahead" -gt 0 ] 2>/dev/null; then
    log "> Skipping pull -- \"$CHECKED_OUT_BRANCH\" has $local_ahead unpushed commit(s), no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "$local_ahead unpushed commit(s), no pull"
    return
  fi

  log "> git pull origin $CHECKED_OUT_BRANCH..."
  if ! run git pull origin "$CHECKED_OUT_BRANCH"; then markfail "$sp_type" "$sp_repo" "git pull origin $CHECKED_OUT_BRANCH"; fi
}

# --- original counting approach ---
count=$(wc -l < "../../app_config.env")

cd ../../
RepoDirName=$(basename "$(pwd)")
cd ../

for ((i=1;i<=count;i++)); do
  eval asset='$'ASSET$i
  if [ ! -z "$asset" ]; then
    asset=$(sed 's/ //g' <<< "$asset")
    log "############################### BEGIN Asset $i: $asset ###############################"
    if [ ! -d "$asset" ]; then
      log
      log "****************************************************"
      log "$asset does not exist; Run ./clone.zsh"
      log "****************************************************"
      log
    else
      cd "$asset"
      checkout_branch "ASSET" "$asset"
      safe_pull "ASSET" "$asset"

      log "################################ END Asset $i: $asset ################################"
      log
      cd ..
    fi
  fi
done

for ((i=1;i<=count;i++)); do
  eval client='$'CLIENT$i
  if [ ! -z "$client" ]; then
    client=$(sed 's/ //g' <<< "$client")
    log "############################### BEGIN Client $i: $client ###############################"
    if [ ! -d "$client" ]; then
      log
      log "***************************************************************************************"
      log "$client does not exist; Run ./clone.zsh then rerun this script"
      log "***************************************************************************************"
      log
    else
      cd "$client"
      checkout_branch "CLIENT" "$client"
      safe_pull "CLIENT" "$client"

      log "> npm ci..."
      if ! run npm ci; then markfail "CLIENT" "$client" "npm ci"; fi

      log "> npm run build..."
      if ! run npm run build; then markfail "CLIENT" "$client" "npm run build"; fi

      log "################################ END Client $i: $client ################################"
      log
      cd ..
    fi
  fi
done

cd "$RepoDirName/linux/scripts"

# --- concise summary ---
echo
echo "================================= SUMMARY ================================="
if [ "$FAILCOUNT" -eq 0 ]; then
  echo "All builds succeeded."
else
  echo "Failed steps: $FAILCOUNT"
  for f in "${FAILS[@]}"; do
    echo "  $f"
  done
fi
if [ "$SKIPCOUNT" -gt 0 ]; then
  echo
  echo "Skipped pulls: $SKIPCOUNT"
  for s in "${SKIPS[@]}"; do
    echo "  $s"
  done
fi
echo
echo "Full log: \"$LOG\""
echo "==========================================================================="

if [ "$FAILCOUNT" -gt 0 ]; then
  exit 1
fi
exit 0

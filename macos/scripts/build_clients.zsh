#!/usr/bin/env zsh

# Run from: pankosmia/<repo-name>/linux/scripts
# Usage:
#   ./build_clients.zsh [branch] [-d]
# Examples:
#   ./build_clients.zsh              # defaults to "main"
#   ./build_clients.zsh dev          # tries dev → qa → main
#   ./build_clients.zsh qa -d        # tries qa → main, deletes past logs
#   ./build_clients.zsh -d dev       # same as above, flags and branch in any order

source ../../app_config.env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- parse args (-d flag and optional branch) ---
deleteLogs="-no"
BRANCH=""
while [ $# -gt 0 ]; do
  if [ "$1" = "-d" ]; then
    deleteLogs="-d"
  elif [ -z "$BRANCH" ]; then
    BRANCH="$1"
  fi
  shift
done

# Default branch to main if not provided
if [ -z "$BRANCH" ]; then
  BRANCH="main"
fi

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

# --- checkout with fallback logic ---
checkout_branch() {
  local cb_type="$1"
  local cb_repo="$2"
  local branch_lower="${BRANCH:l}"   # zsh lowercase

  log "> git checkout $BRANCH..."
  if run git checkout "$BRANCH"; then
    return
  fi

  # Branch didn't exist — apply fallback logic
  if [ "$branch_lower" = "dev" ]; then
    log "> Branch \"dev\" not found, trying \"qa\"..."
    if run git checkout qa; then
      return
    fi
    log "> Branch \"qa\" not found, falling back to \"main\"..."
    if ! run git checkout main; then
      markfail "$cb_type" "$cb_repo" "git checkout main (fallback from dev)"
    fi
    return
  fi

  if [ "$branch_lower" = "qa" ]; then
    log "> Branch \"qa\" not found, falling back to \"main\"..."
    if ! run git checkout main; then
      markfail "$cb_type" "$cb_repo" "git checkout main (fallback from qa)"
    fi
    return
  fi

  # Any other branch — fall back to main
  log "> Branch \"$BRANCH\" not found, falling back to \"main\"..."
  if ! run git checkout main; then
    markfail "$cb_type" "$cb_repo" "git checkout main (fallback from $BRANCH)"
  fi
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

      log "> git pull..."
      if ! run git pull; then markfail "ASSET" "$asset" "git pull"; fi

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

      log "> git pull..."
      if ! run git pull; then markfail "CLIENT" "$client" "git pull"; fi

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
    echo "$f"
  done
fi
echo
echo "Full log: \"$LOG\""
echo "==========================================================================="

if [ "$FAILCOUNT" -gt 0 ]; then
  exit 1
fi
exit 0

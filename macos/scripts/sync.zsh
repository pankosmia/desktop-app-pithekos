#!/usr/bin/env zsh

set -e
set -u # Zsh will want 1-based arrays, not 0-based.

doSync() {
  git fetch upstream main
  git merge --no-log --no-ff --no-commit upstream/main > /dev/null 2>&1 || true

  # --- Protected files: these should not be overwritten by the upstream merge ---
  PROTECTED_FILES=(
    "package-lock.json"
    "globalBuildResources/favicon.ico"
    "globalBuildResources/icon.icns"
    "globalBuildResources/icon.ico"
    "globalBuildResources/linux_icon.png"
    "globalBuildResources/favicon.png"
    "globalBuildResources/favicon@1.25x.png"
    "globalBuildResources/favicon@1.5x.png"
    "globalBuildResources/favicon@1.75x.png"
    "globalBuildResources/favicon@2x.png"
    "globalBuildResources/i18nPatch.json"
    "globalBuildResources/theme.json"
    "branding/building_blocks/for_favicon_ico/favicon_16x16.png"
    "branding/building_blocks/for_favicon_ico/favicon_32x32.png"
    "branding/building_blocks/for_icon_icns/icon_128x128.png"
    "branding/building_blocks/for_icon_icns/icon_128x128@2x.png"
    "branding/building_blocks/for_icon_icns/icon_16x16.png"
    "branding/building_blocks/for_icon_icns/icon_16x16@2x.png"
    "branding/building_blocks/for_icon_icns/icon_256x256.png"
    "branding/building_blocks/for_icon_icns/icon_256x256@2x.png"
    "branding/building_blocks/for_icon_icns/icon_32x32.png"
    "branding/building_blocks/for_icon_icns/icon_32x32@2x.png"
    "branding/building_blocks/for_icon_icns/icon_512x512.png"
    "branding/building_blocks/for_icon_icns/icon_512x512@2x.png"
    "branding/building_blocks/for_icon_ico/win_icon_16x16.png"
    "branding/building_blocks/for_icon_ico/win_icon_256x256.png"
    "branding/building_blocks/for_icon_ico/win_icon_32x32.png"
    "branding/building_blocks/for_icon_ico/win_icon_48x48.png"
    "branding/source/favicon.png"
    "branding/source/mac_icon.png"
    "branding/source/win_icon.png"
    "branding/source/favicon.svg"
    "branding/source/mac_icon.svg"
    "branding/source/win_icon.svg"
    "branding/source/artwork/favicon_transparent_square_blue-turqoise.psd"
    "branding/source/artwork/logo_512.png"
    "branding/source/artwork/logo_favicon_inkscape.svg"
    "branding/source/artwork/logo_inkscape.svg"
    "branding/source/artwork/logo_macos.psd"
    "branding/source/artwork/logo_windows.psd"
  )

  # --- Get the list of files actually staged by the merge ---
  local staged_output
  staged_output="$(git diff --name-only --cached)"
  local staged_files=("${(@f)staged_output}")

  local excluded_count=0
  local excluded_list=()

  for staged_file in "${staged_files[@]}"; do
    # Skip empty lines (e.g., if nothing was staged)
    [[ -z "$staged_file" ]] && continue
    for protected in "${PROTECTED_FILES[@]}"; do
      if [[ "$staged_file" == "$protected" ]]; then
        git reset "$staged_file" > /dev/null 2>&1
        git checkout "$staged_file" > /dev/null 2>&1 || true
        excluded_count=$((excluded_count + 1))
        excluded_list+=("$staged_file")
        break
      fi
    done
  done

  # --- Print a clean summary ---
  echo
  if [[ "$excluded_count" -eq 0 ]]; then
    echo "     No protected files were affected by this sync."
  else
    echo "     ${excluded_count} protected file(s) were excluded from this sync:"
    echo
    for item in "${excluded_list[@]}"; do
      echo "        - ${item}"
    done
    echo
    echo "     These files were reset to preserve this repo's versions."
  fi
  echo
  echo "     *******************************************************************************"
  echo "     * Now review staged changes, and commit if there are no conflicts, then push. *"
  echo "     *******************************************************************************"
  echo
}

echo

# Do not ask if the latest is already pulled if the -p $1 positional argument is provided
askIfPulled="${1:-yes}" # -p means "no"
if ! [[ $askIfPulled =~ ^(-p) ]]; then
  while true; do
    read "choice?Is the latest is already pulled? [Y/n]: "
    case $choice in 
      "y" | "Y" | "" ) echo
        echo "Continuing..."
        break
        ;;
      [nN] ) echo
        echo "     Exiting...";
        echo
        echo "     Pull the latest, then re-run this script."
        echo
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
        echo
        ;;
    esac
  done
fi

cd ../../

remote="$(git remote 2>/dev/null || true)"
remotearray=("${(@f)remote}")  # split on newlines into 1-based array (Not 0 based!)

config="$(git config --local --list 2>/dev/null || true)"
configarray=("${(@f)config}")  # split on newlines into 1-based array (Not 0 based!)
countb=${#configarray[@]}

# Don't proceed if the origin is not set.
if [ -z "${remotearray[1]:-}" ]; then
  echo "origin is not set"
  echo "add origin, then re-run this script"
  cd windows/scripts/
  exit;
else
  echo "${remotearray[1]} is set"
fi

origintest=good_if_not_changed
upstreamtest=different_if_not_changed

for (( i=1; i<=countb; i++ )); do
  # Don't proceed if the origin is the intended upstream.
  if [[ "${configarray[$i]}" == "remote.origin.url=https://github.com/pankosmia/desktop-app-template.git" ]]; then
    origintest=stop_because_is_set_to_desired_upstream
    echo
    echo "origin is set to https://github.com/pankosmia/desktop-app-template.git"
    echo "This script is not meant to be run on this repo as it expects that that to be the upstream, not the origin."
    echo
    echo "Exiting ...."
    echo
    cd windows/scripts/
    exit;
  fi
  # This assumes the origin record will always be returned on an earlier line that the upstream record.
  # Proceed if the origin is set.
  if [ "$origintest"=="good_if_not_changed" ]; then
      # Proceed if the upstream is already set as expected.
    if [[ "${configarray[$i]}" == "remote.upstream.url=https://github.com/pankosmia/desktop-app-template.git" ]]; then
      upstreamtest=as_expected
      echo "upstream is confirmed as set to https://github.com/pankosmia/desktop-app-template.git"
      up=$i
      doSync
      cd windows/scripts/
      exit;
    fi
  fi
done
# This assumes the origin record will always be returned on an earlier line that the upstream record.
# Proceed if the origin is set.
if [ "$origintest"="good_if_not_changed" ]; then
  # Set the upstream and proceed if it is not yet set.
  if [ -z "${remotearray[2]:-}" ]; then # 1-based array!!!!
    git remote add upstream https://github.com/pankosmia/desktop-app-template.git
    set upstreamtest=set
    echo upstream has been set to https://github.com/pankosmia/desktop-app-template.git
    doSync
    cd windows/scripts/
    exit;
  fi
fi

# Don't proceed if the upstream is set elsewhere.
if [[ "$upstreamtest" == "different_if_not_changed" ]]; then
  echo
  echo "The upstream is set to: ${configarray[$up]}"
  echo "However, this script is written for an upstream that is set to https://github.com/pankosmia/desktop-app-template.git"
  echo
  goto :end
fi

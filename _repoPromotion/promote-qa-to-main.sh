#!/usr/bin/env bash
#
# Opens a PR promoting 'qa' → 'main' in every repo listed in repos.env.
# It only opens PRs; it never merges them. Existing open 'qa' → 'main'
# PRs are detected and left untouched.
#
# Flags:
#   --dry-run
#       Runs all read-only checks live against GitHub (branch existence,
#       direction/divergence comparison, and duplicate-PR detection), then
#       reports what it WOULD do — but does not open any pull requests.
#
# Requirements:
#   - Linux
#   - jq
#   - GitHub CLI (gh) installed
#   - Run `gh auth login` once (per account/host)
#   - repos.env and promote-lib.sh exist in this same directory

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/promote-lib.sh"

run_promotion \
  "main" \
  "qa" \
  "Promote qa to main" \
  "Promotion from qa to main." \
  "$@"

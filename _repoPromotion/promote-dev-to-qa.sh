#!/usr/bin/env bash
#
# Opens a pull request promoting 'dev' -> 'qa' in every repo listed in
# repos.env. It only opens PRs; it never merges them. Existing open dev -> qa
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
#   - GitHub CLI (gh) installed
#   - Run `gh auth login` once (per account/host)
#   - repos.env and promote-lib.sh exist in this same directory

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/promote-lib.sh"

run_promotion \
  "qa" \
  "dev" \
  "Promote dev to qa" \
  "Automated promotion from dev to qa." \
  "$@"

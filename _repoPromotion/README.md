## Repo promotion dev → qa → main

### Overview
`promote-dev-to-qa.sh` and `promote-qa-to-main.sh` open PRs promoting 'dev' →  'qa' or 'qa' →  'main' on every repo listed in `repos.env`.
- Only opens PRs; never merges them.
- Existing open 'dev' →  'qa' or 'qa' → 'main' PRs are detected and left untouched.

### Tips
1. Always run first with the `--dry-run` flag to identify items to address.
   - Runs all read-only checks live against GitHub (branch existence, direction/divergence comparison, and duplicate-PR detection), then reports what it WOULD do — but does not open any PRs.
2. When excluding a repo from promotion, note that commenting out a repo from `repos.env` is an alternative to deleting it completely from the file.
   -  This is using `repos.env` instead of `app_config.env` so the list of repos does not always have to match the app's clients.

### Requirements:
- Linux
- GitHub CLI (gh) installed
- Run `gh auth login` once (per account/host)
- `repos.env` and `promote-lib.sh` remain in the same directory as the scripts listed in "Overview".

### One-time setup
1. Install GitHub CLI (gh). You'll get prompted if it isn't installed. For Ubuntu:
```
> sudo apt update
> sudo apt install gh
```
2. Run `gh auth login` once. You'll get prompted if this hasn't been run.
    - _host:_ GitHub.com
    - _Preferred protocol for Git operations:_ This script does no git operation, but this needs an answer; `https` has one less step.[^1]
      - With https, you can answer "_Authenticate Git with your GitHub credentials (Y/n):_" with  "n" as the script doesn't use git, though it will still work just the same if you go with "Y".
    - _How would you like to authenticate GitHub CLI?_: It is simplest to use the "login with a web browser" option. It will show a one-time device code. When you press Enter, the browser will open for the code paste and authorization.[^2]

### Use

1. `cd _repoPromotion`
2. `./promote-dev-to-qa.sh --dry-run`
3. Review the output to confirm it is what you intend to have happen.
4. `./promote-dev-to-qa.sh`
5. When Approving these PR's -- Be intentional to **_not_** `delete the branch` afterwards, so as to not delete `dev` (or `qa` later)!

After PRs are accepted on all `qa` branches and the next promotion step is confirmed ready, repeat with the qa to main script.
___
[^1]: If you pick ssh, then it'll offer to generate/upload a key (you can skip with --skip-ssh-key).

[^2]: If you instead use a token, the minimum required scopes for this are `repo`, `read:org`, and `gist`
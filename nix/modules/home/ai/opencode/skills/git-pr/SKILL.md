---
name: git-pr
description: Use when the user asks to open, create, or draft a pull request. Builds the title and description from the branch diff and opens it with gh.
---

# git-pr

1. Find the base: `git remote show origin | sed -n 's/.*HEAD branch: //p'`.
2. Read the full branch, not just the last commit: `git log <base>..HEAD --oneline` and `git diff <base>...HEAD`.
3. Title: short, imperative, <= 70 chars. Body: `## Summary` (1-3 bullets on what and why) and `## Test plan` (checklist of what was verified).
4. Make sure the branch is pushed only if the user asked to push/open the PR: `git push -u origin HEAD`.
5. `gh pr create --base <base> --title "..." --body "..."`. Add `--draft` if the work is unfinished. Return the PR URL.

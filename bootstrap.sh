#!/usr/bin/env bash
# Install the agent caller workflows + OAuth secret + ordering label into target repos.
# Usage:
#   ./bootstrap.sh --dry-run owner/repo [owner/repo ...]
#   ./bootstrap.sh owner/repo [owner/repo ...]
#   ./bootstrap.sh --all            # every non-fork, non-archived repo you own
# Requires: gh (authenticated), and CLAUDE_CODE_OAUTH_TOKEN in the environment.
set -euo pipefail

DRY=0; ALL=0; REPOS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --all) ALL=1 ;;
    *) REPOS+=("$a") ;;
  esac
done

: "${CLAUDE_CODE_OAUTH_TOKEN:?export CLAUDE_CODE_OAUTH_TOKEN before running}"
OWNER="$(gh api user --jq .login)"
if [ "$ALL" = 1 ]; then
  mapfile -t REPOS < <(gh repo list "$OWNER" --no-archived --source --limit 500 --json nameWithOwner --jq '.[].nameWithOwner')
fi
[ "${#REPOS[@]}" -gt 0 ] || { echo "no repos given"; exit 1; }

run() { if [ "$DRY" = 1 ]; then echo "DRY: $*"; else eval "$*"; fi; }

for repo in "${REPOS[@]}"; do
  echo "== $repo =="
  for role in explorer fix grill; do
    src="templates/agent-${role}.yml"
    content="$(sed "s#OWNER/agent-issue-ops#${OWNER}/agent-issue-ops#g" "$src" | base64)"
    path=".github/workflows/agent-${role}.yml"
    # Create or update the file on the default branch via the contents API.
    run "gh api -X PUT \"repos/${repo}/contents/${path}\" \
      -f message='chore: install agent-${role} workflow' \
      -f content='${content}' \
      -f sha=\"\$(gh api repos/${repo}/contents/${path} --jq .sha 2>/dev/null || true)\" >/dev/null"
  done
  run "gh secret set CLAUDE_CODE_OAUTH_TOKEN -R \"${repo}\" --body \"\${CLAUDE_CODE_OAUTH_TOKEN}\""
  # Ordering label: prerequisite issues that must be done before dependents.
  run "gh label create do-first -R \"${repo}\" --color B60205 --description 'Do before other issues (prerequisite/blocker)' --force"
done
echo "done"

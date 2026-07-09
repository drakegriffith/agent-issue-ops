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

  # ── agent-issue-ops standard label taxonomy (idempotent; --force updates in place) ──
  # PRIORITY — traffic light. RESERVED hues: nothing else is red/orange/yellow/green.
  run "gh label create P0-critical  -R \"${repo}\" --color d73a4a --description '🔴 Critical — drop everything; safety / data-loss / security' --force"
  run "gh label create P1-high      -R \"${repo}\" --color f66a0a --description '🟠 High — integrity / correctness risk' --force"
  run "gh label create P2-medium    -R \"${repo}\" --color ffd33d --description '🟡 Medium — normal correctness / operator-facing' --force"
  run "gh label create P3-low       -R \"${repo}\" --color 2da44e --description '🟢 Low — refactor / polish / governance' --force"
  # TYPE — what kind of work (non-traffic hues).
  run "gh label create safety       -R \"${repo}\" --color bf3989 --description 'Fail-open / no-autosend / guardrail correctness' --force"
  run "gh label create bug          -R \"${repo}\" --color d876e3 --description 'Defect — wrong behavior' --force"
  run "gh label create code-quality -R \"${repo}\" --color 1b7c83 --description 'Refactor / smell / maintainability' --force"
  run "gh label create spec-gap     -R \"${repo}\" --color 8250df --description 'Diverges from the spec / requirements' --force"
  run "gh label create enhancement  -R \"${repo}\" --color a2eeef --description 'New capability' --force"
  run "gh label create docs         -R \"${repo}\" --color 0969da --description 'Documentation / notes' --force"
  # WORKFLOW — state, not kind.
  run "gh label create epic         -R \"${repo}\" --color 24292f --description 'Tracking issue (rolls up child issues via a checklist)' --force"
  run "gh label create blocked      -R \"${repo}\" --color 6e7781 --description 'Has a hard prerequisite — see Blocked by #N in the issue body' --force"
  # do-first: ordering signal @agent-explorer applies to a prerequisite that gates others.
  # Neutral charcoal (off the reserved traffic-light hues); pairs with 'blocked' on the dependent.
  run "gh label create do-first     -R \"${repo}\" --color 444d56 --description 'Prerequisite — do before dependents; pairs with blocked' --force"
  # AREA/subsystem labels are created ad-hoc in blue (0969da), e.g.:
  #   gh label create publish-queue -R \"${repo}\" --color 0969da --description 'Publish Queue subsystem' --force
done
echo "done"

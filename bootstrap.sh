#!/usr/bin/env bash
# Install the agent caller workflows + Codex auth secret + ordering label into target repos.
# Usage:
#   ./bootstrap.sh --dry-run owner/repo [owner/repo ...]
#   ./bootstrap.sh owner/repo [owner/repo ...]
#   ./bootstrap.sh --all            # every non-fork, non-archived repo you own
# Requires: gh (authenticated), and a ChatGPT-plan Codex login stored as a file:
#   set cli_auth_credentials_store = "file" in ~/.codex/config.toml, then `codex login`.
# Re-running this script is also the RESEED path when CI auth goes stale.
set -euo pipefail

DRY=0; ALL=0; REPOS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --all) ALL=1 ;;
    *) REPOS+=("$a") ;;
  esac
done

CODEX_AUTH_FILE="${CODEX_HOME:-$HOME/.codex}/auth.json"
if [ ! -f "$CODEX_AUTH_FILE" ]; then
  echo "missing $CODEX_AUTH_FILE — set cli_auth_credentials_store = \"file\" in ~/.codex/config.toml, then run: codex login" >&2
  exit 1
fi
if command -v jq >/dev/null; then
  AUTH_MODE="$(jq -r '.auth_mode // empty' "$CODEX_AUTH_FILE")"
  [ "$AUTH_MODE" = "chatgpt" ] || { echo "auth_mode in $CODEX_AUTH_FILE is '$AUTH_MODE', expected 'chatgpt' (ChatGPT-plan login)" >&2; exit 1; }
fi
OWNER="$(gh api user --jq .login)"
if [ "$ALL" = 1 ]; then
  mapfile -t REPOS < <(gh repo list "$OWNER" --no-archived --source --limit 500 --json nameWithOwner --jq '.[].nameWithOwner')
fi
[ "${#REPOS[@]}" -gt 0 ] || { echo "no repos given"; exit 1; }

run() { if [ "$DRY" = 1 ]; then echo "DRY: $*"; else eval "$*"; fi; }

# Contents-API PUT with retry: sequential PUTs to the same branch can 409 on a
# stale head right after the previous install commit. Refetch the sha and retry.
put_file() {
  local repo="$1" path="$2" content="$3" attempt sha
  for attempt in 1 2 3; do
    sha="$(gh api "repos/${repo}/contents/${path}" --jq .sha 2>/dev/null || true)"
    if gh api -X PUT "repos/${repo}/contents/${path}" \
      -f message="chore: install ${path##*/}" \
      -f content="${content}" \
      -f sha="${sha}" >/dev/null 2>&1; then
      return 0
    fi
    echo "  retry ${attempt}/3: ${path} (branch head race)" >&2
    sleep 2
  done
  echo "failed to install ${path} in ${repo}" >&2
  return 1
}

for repo in "${REPOS[@]}"; do
  echo "== $repo =="
  for role in explorer fix grill; do
    src="templates/agent-${role}.yml"
    content="$(sed "s#OWNER/agent-issue-ops#${OWNER}/agent-issue-ops#g" "$src" | base64)"
    path=".github/workflows/agent-${role}.yml"
    # Create or update the file on the default branch via the contents API.
    if [ "$DRY" = 1 ]; then
      echo "DRY: install ${path} in ${repo}"
    else
      put_file "$repo" "$path" "$content"
    fi
  done
  # stdin keeps the token out of the command string (and out of --dry-run output);
  # older gh versions lack --body-file.
  run "gh secret set CODEX_AUTH_JSON -R \"${repo}\" < \"\${CODEX_AUTH_FILE}\""
  # Full standard taxonomy (priority + type + workflow + routing) — the explorer
  # applies route:* labels, so they must exist wherever the agents are installed.
  run "bash \"$(dirname "$0")/label-kit/setup-labels.sh\" \"${repo}\""
done
echo "done"

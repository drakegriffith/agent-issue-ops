#!/usr/bin/env bash
# Install the gh-label-kit as a Claude Code skill on THIS machine.
# Run once after pulling the repo:  bash label-kit/install.sh
# Afterwards the skill is available in every repo you open (say "apply our label structure").
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills/gh-label-kit"

mkdir -p "$DEST"
cp -R "$SRC/." "$DEST/"
chmod +x "$DEST/setup-labels.sh" 2>/dev/null || true

echo "✓ Installed gh-label-kit → $DEST"
echo "  Next: from any repo, run  bash $DEST/setup-labels.sh  (or tell your terminal: \"apply our label structure\")"
echo "  Onboarding: $DEST/references/agent-workflow.md"

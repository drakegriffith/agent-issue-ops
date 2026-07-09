#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# agent-issue-ops standard GitHub issue-label taxonomy.
# Idempotent: safe to re-run; `--force` updates color/description in place.
# Works on ANY repo. Requires the GitHub CLI, authenticated (`gh auth login`).
#
#   Usage:  bash setup-labels.sh [owner/repo]
#           (no arg = the repo of the current directory)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Applying the agent-issue-ops standard label taxonomy to: $REPO"

lbl() { gh label create "$1" -R "$REPO" --color "$2" --description "$3" --force >/dev/null && echo "  ✓ $1"; }

# ── PRIORITY — traffic light. RESERVED hues: nothing else is red/orange/yellow/green. ──
lbl "P0-critical" d73a4a "🔴 Critical — drop everything; safety / data-loss / security"
lbl "P1-high"     f66a0a "🟠 High — integrity / correctness risk"
lbl "P2-medium"   ffd33d "🟡 Medium — normal correctness / operator-facing"
lbl "P3-low"      2da44e "🟢 Low — refactor / polish / governance"

# ── TYPE — what kind of work (non-traffic hues). ──
lbl "safety"       bf3989 "Fail-open / no-autosend / guardrail correctness"
lbl "bug"          d876e3 "Defect — wrong behavior"
lbl "code-quality" 1b7c83 "Refactor / smell / maintainability"
lbl "spec-gap"     8250df "Diverges from the spec / requirements"
lbl "enhancement"  a2eeef "New capability"
lbl "docs"         0969da "Documentation / notes"

# ── WORKFLOW — state, not kind. ──
lbl "epic"     24292f "Tracking issue (rolls up child issues via a checklist)"
lbl "blocked"  6e7781 "Has a hard prerequisite — see Blocked by #N in the issue body"
# do-first: the prerequisite that gates others (pairs with 'blocked' on the dependent).
# Neutral charcoal — off the reserved traffic-light hues so it never reads as a priority.
lbl "do-first" 444d56 "Prerequisite — do before dependents; pairs with blocked"

echo "Done."
echo "Area/subsystem labels (e.g. 'publish-queue', 'billing') are created ad-hoc in blue (0969da):"
echo "  gh label create <area> -R $REPO --color 0969da --description '<subsystem> …'"

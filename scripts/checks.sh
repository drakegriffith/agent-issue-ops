#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "CHECK FAIL: $1" >&2; exit 1; }

# 1. All workflow/template YAML parses.
for f in .github/workflows/*.yml templates/*.yml; do
  [ -e "$f" ] || continue
  python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" || fail "invalid YAML: $f"
done

RW=.github/workflows/agent.reusable.yml
[ -f "$RW" ] || fail "missing $RW"

# 2. Reusable workflow shape.
grep -q "workflow_call" "$RW" || fail "reusable workflow missing workflow_call"
grep -q "claude-code-action@v1" "$RW" || fail "action not pinned to @v1"
grep -q "claude_code_oauth_token" "$RW" || fail "OAuth token input missing"
grep -q "anthropic_api_key" "$RW" && fail "must not use anthropic_api_key"

# 3. Explorer role prompt present + read-only intent.
grep -qi "@agent-explorer" "$RW" || fail "explorer marker missing"
grep -qi "read-only" "$RW" || fail "explorer read-only intent missing"
grep -qi "recommend" "$RW" || fail "explorer recommendation step missing"
grep -qi "do-first" "$RW" || fail "explorer do-first ordering label step missing"

# 4. Fix role: TDD + PR-only, never merge.
grep -qi "@agent-fix" "$RW" || fail "fix marker missing"
grep -qi "TDD\|failing test" "$RW" || fail "fix TDD step missing"
grep -qi "pull request" "$RW" || fail "fix PR step missing"
grep -qi "never merge\|NEVER merge" "$RW" || fail "fix no-merge rule missing"

# 5. Grill role: questions only, no code.
grep -qi "@agent-grill" "$RW" || fail "grill marker missing"
grep -qi "questions" "$RW" || fail "grill questions step missing"

# 6. Templates: trigger phrases + least-privilege permissions.
grep -q '"@agent-explorer"' templates/agent-explorer.yml || fail "explorer template trigger missing"
grep -q '"@agent-fix"' templates/agent-fix.yml || fail "fix template trigger missing"
grep -q '"@agent-grill"' templates/agent-grill.yml || fail "grill template trigger missing"
grep -q "pull-requests: write" templates/agent-fix.yml || fail "fix template needs PR write"
grep -q "pull-requests: write" templates/agent-explorer.yml && fail "explorer must NOT have PR write"
grep -q "pull-requests: write" templates/agent-grill.yml && fail "grill must NOT have PR write"

# 7. Bootstrap exists, is executable, supports --dry-run + installs the label taxonomy.
[ -x bootstrap.sh ] || fail "bootstrap.sh missing or not executable"
grep -q "dry-run" bootstrap.sh || fail "bootstrap.sh must support --dry-run"
grep -q "gh label create do-first" bootstrap.sh || fail "bootstrap.sh must create the do-first label"
grep -q "gh label create P0-critical" bootstrap.sh || fail "bootstrap.sh must install the priority taxonomy (P0-critical)"
grep -q "gh label create blocked" bootstrap.sh || fail "bootstrap.sh must install the workflow taxonomy (blocked)"
command -v shellcheck >/dev/null && { shellcheck bootstrap.sh scripts/checks.sh || fail "shellcheck"; }

echo "checks: OK"

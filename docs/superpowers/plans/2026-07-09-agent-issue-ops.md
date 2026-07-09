# Agent Issue-Ops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship mention-triggered GitHub issue agents (`@agent-explorer`, `@agent-fix`, `@agent-grill`) that run the Pocock protocol on GitHub Actions using a Claude Max OAuth token, with human-gated handoff and PR-only fixes, rollable to all repos via one script.

**Architecture:** One central **reusable workflow** (`agent.reusable.yml`) in this repo holds all three role prompts inline and runs `anthropics/claude-code-action@v1`. Each target repo gets three tiny **caller workflows** (from `templates/`) that set the per-agent trigger phrase + least-privilege `permissions` and call the reusable workflow. A `bootstrap.sh` installs the callers + the OAuth secret across all repos.

**Tech Stack:** GitHub Actions (`workflow_call` reusable workflows), `anthropics/claude-code-action@v1`, `gh` CLI, bash, `python3` (YAML validation in the check harness).

## Global Constraints

- Action pinned to `anthropics/claude-code-action@v1`.
- Auth input: `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}` — never `anthropic_api_key`.
- Trigger phrases exact: `@agent-explorer`, `@agent-fix`, `@agent-grill`.
- Least-privilege lives in the **caller** workflows: explorer/grill get `issues: write, contents: read` only; fix gets `contents: write, pull-requests: write, issues: write`.
- `@agent-fix` opens a PR and **never** merges (no `gh pr merge`); single branch only.
- `@agent-explorer` and `@agent-grill` never edit code or open PRs.
- Handoff is human-gated: an agent recommends the next one by name; it never summons it.
- Ordering label: `do-first` marks a prerequisite issue (must be resolved before dependents; e.g. a gating grill-me). Most issues carry no label. `@agent-explorer` applies `do-first` when it judges the issue gates others; `bootstrap.sh` creates the label per repo.
- This repo (`agent-issue-ops`) contains **no secrets** and is **public** so other repos can call its reusable workflow. (Alternative: keep private and enable Settings → Actions → "Accessible from repositories owned by <user>".)
- Validate end-to-end on `inbox-cockpit` before running the all-repos bootstrap.

## File Structure

```
agent-issue-ops/
├── .github/workflows/agent.reusable.yml   # reusable workflow; 3 inline role prompts; runs claude-code-action
├── templates/agent-explorer.yml           # caller installed into each target repo (read-only perms)
├── templates/agent-fix.yml                # caller installed into each target repo (write perms)
├── templates/agent-grill.yml              # caller installed into each target repo (read-only perms)
├── scripts/checks.sh                      # local validation: YAML valid + required role/permission markers
├── bootstrap.sh                           # gh loop: install callers + set secret across repos (has --dry-run)
└── README.md                              # usage + setup (token, public repo, bootstrap)
```

---

### Task 1: Check harness + reusable workflow (explorer role)

**Files:**
- Create: `scripts/checks.sh`
- Create: `.github/workflows/agent.reusable.yml`

**Interfaces:**
- Produces: `scripts/checks.sh` (run with no args; exit 0 = pass). Later tasks extend its assertion list.
- Produces: reusable workflow `agent.reusable.yml` with `workflow_call` inputs `role` (string), `trigger_phrase` (string) and required secret `CLAUDE_CODE_OAUTH_TOKEN`. Callers consume this signature.

- [ ] **Step 1: Write the failing check harness**

Create `scripts/checks.sh`:

```bash
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

echo "checks: OK"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/checks.sh`
Expected: FAIL with `CHECK FAIL: missing .github/workflows/agent.reusable.yml`

- [ ] **Step 3: Write the reusable workflow with the explorer role**

Create `.github/workflows/agent.reusable.yml`:

```yaml
name: agent-reusable
on:
  workflow_call:
    inputs:
      role:
        description: "explorer | fix | grill"
        required: true
        type: string
      trigger_phrase:
        required: true
        type: string
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN:
        required: true
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Select role prompt
        run: |
          set -euo pipefail
          case "${{ inputs.role }}" in
            explorer)
              cat > /tmp/agent-prompt.md <<'PROMPT'
          You are @agent-explorer, mentioned on a GitHub issue in this repo.
          You are READ-ONLY: you may NOT change code, create branches, or open PRs.
          1. Read the issue title, body, and every comment.
          2. Explore the repository for all context relevant to this issue: the files
             involved (path:line), how they work today, related tests, the repo's
             AGENTS.md / CLAUDE.md coding standards, and any spec/PRD it references.
          3. Compact it into a TIGHT brief a fresh engineer could act on without
             re-exploring: the problem, exact files/functions, the constraints, and
             the smallest correct approach.
          4. Recommend exactly ONE next move and name the agent:
             - "@agent-fix" if the issue is well-scoped and safe to implement now.
             - "@agent-grill" if it is under-specified and needs sharpening first.
             Give a one-line reason.
          5. If this issue must be resolved BEFORE other issues in the repo (it gates
             dependent work — e.g. a large grill-me others build on), apply the
             "do-first" label to the issue and say so in your brief. Most minor bug
             fixes are order-independent — leave them unlabeled.
          Post the brief + recommendation as ONE issue comment. Do NOT summon the next
          agent (the human will). Do NOT edit files (labelling the issue is allowed).
          PROMPT
              ;;
            *)
              echo "unknown role: ${{ inputs.role }}" >&2; exit 1 ;;
          esac
          {
            echo "AGENT_PROMPT<<PROMPT_EOF"
            cat /tmp/agent-prompt.md
            echo "PROMPT_EOF"
          } >> "$GITHUB_ENV"
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          trigger_phrase: ${{ inputs.trigger_phrase }}
          prompt: ${{ env.AGENT_PROMPT }}
```

- [ ] **Step 4: Run the check to verify it passes**

Run: `bash scripts/checks.sh`
Expected: `checks: OK`

- [ ] **Step 5: Commit**

```bash
chmod +x scripts/checks.sh
git add scripts/checks.sh .github/workflows/agent.reusable.yml
git commit -m "feat: reusable agent workflow with explorer role + check harness"
```

---

### Task 2: Add the fix role

**Files:**
- Modify: `.github/workflows/agent.reusable.yml` (add `fix)` case branch)
- Modify: `scripts/checks.sh` (add fix assertions)

**Interfaces:**
- Consumes: reusable workflow from Task 1.
- Produces: `role: fix` branch usable by the fix caller in Task 4.

- [ ] **Step 1: Add the failing fix assertions to the harness**

Add before the final `echo "checks: OK"` in `scripts/checks.sh`:

```bash
# Fix role: TDD + PR-only, never merge.
grep -qi "@agent-fix" "$RW" || fail "fix marker missing"
grep -qi "TDD\|failing test" "$RW" || fail "fix TDD step missing"
grep -qi "pull request" "$RW" || fail "fix PR step missing"
grep -qi "never merge\|NEVER merge" "$RW" || fail "fix no-merge rule missing"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/checks.sh`
Expected: FAIL with `CHECK FAIL: fix marker missing`

- [ ] **Step 3: Add the fix case branch**

In `agent.reusable.yml`, add this branch to the `case` (before the `*)` default):

```yaml
            fix)
              cat > /tmp/agent-prompt.md <<'PROMPT'
          You are @agent-fix, mentioned on a GitHub issue in this repo.
          Follow the Pocock implement protocol, test-first:
          1. Read the issue and the @agent-explorer brief in the comments (your context).
          2. Read the repo's AGENTS.md / CLAUDE.md coding standards and matching tests.
          3. TDD: write a FAILING test capturing the fix, run it and confirm it fails,
             then write the minimal code to pass, then run the full suite green.
          4. Self-review the diff on two axes and fix what you find: Standards (repo's
             documented standards) and Spec (does exactly what the issue asked, no more).
          5. Open ONE single-branch pull request proposing merge into the default branch,
             titled for the issue and linking it (Closes #N).
          HARD RULES: one branch only; open a PR but NEVER merge it; if the issue is too
          large or ambiguous to fix safely, stop and comment recommending "@agent-grill".
          PROMPT
              ;;
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash scripts/checks.sh`
Expected: `checks: OK`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/agent.reusable.yml scripts/checks.sh
git commit -m "feat: add fix role (TDD, PR-only) to reusable workflow"
```

---

### Task 3: Add the grill role

**Files:**
- Modify: `.github/workflows/agent.reusable.yml` (add `grill)` case branch)
- Modify: `scripts/checks.sh` (add grill assertions)

**Interfaces:**
- Consumes: reusable workflow from Tasks 1–2.
- Produces: `role: grill` branch usable by the grill caller in Task 4.

- [ ] **Step 1: Add the failing grill assertions**

Add before the final `echo "checks: OK"`:

```bash
# Grill role: questions only, no code.
grep -qi "@agent-grill" "$RW" || fail "grill marker missing"
grep -qi "questions" "$RW" || fail "grill questions step missing"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/checks.sh`
Expected: FAIL with `CHECK FAIL: grill marker missing`

- [ ] **Step 3: Add the grill case branch**

Add to the `case` (before `*)`):

```yaml
            grill)
              cat > /tmp/agent-prompt.md <<'PROMPT'
          You are @agent-grill, mentioned on a GitHub issue in this repo.
          The issue is under-specified. Run a grill-me pass BEFORE any code:
          1. Read the issue and any @agent-explorer brief.
          2. Post ONE comment with the smallest set of pointed questions whose answers
             you need to make this issue safe to implement: scope boundaries, acceptance
             criteria, edge cases, and anything ambiguous. No filler.
          3. Do NOT change code and do NOT open a PR.
          When the human answers they will mention "@agent-fix". If the issue is clearly
          scoped after your questions, end your comment recommending "@agent-fix".
          PROMPT
              ;;
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash scripts/checks.sh`
Expected: `checks: OK`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/agent.reusable.yml scripts/checks.sh
git commit -m "feat: add grill role (questions-only) to reusable workflow"
```

---

### Task 4: Caller workflow templates

**Files:**
- Create: `templates/agent-explorer.yml`
- Create: `templates/agent-fix.yml`
- Create: `templates/agent-grill.yml`
- Modify: `scripts/checks.sh` (assert templates' trigger phrases + permissions)

**Interfaces:**
- Consumes: reusable workflow signature `role` + `trigger_phrase` + `secrets: inherit`.
- Produces: three caller files `bootstrap.sh` (Task 5) installs into each repo's `.github/workflows/`. Replace `OWNER` with the actual GitHub owner at bootstrap time.

- [ ] **Step 1: Add failing template assertions**

Add before the final `echo "checks: OK"`:

```bash
# Templates: trigger phrases + least-privilege permissions.
grep -q '"@agent-explorer"' templates/agent-explorer.yml || fail "explorer template trigger missing"
grep -q '"@agent-fix"' templates/agent-fix.yml || fail "fix template trigger missing"
grep -q '"@agent-grill"' templates/agent-grill.yml || fail "grill template trigger missing"
grep -q "pull-requests: write" templates/agent-fix.yml || fail "fix template needs PR write"
grep -q "pull-requests: write" templates/agent-explorer.yml && fail "explorer must NOT have PR write"
grep -q "pull-requests: write" templates/agent-grill.yml && fail "grill must NOT have PR write"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/checks.sh`
Expected: FAIL with `CHECK FAIL: explorer template trigger missing`

- [ ] **Step 3: Write the three templates**

Create `templates/agent-explorer.yml`:

```yaml
name: agent-explorer
on:
  issues:
    types: [opened, edited]
  issue_comment:
    types: [created]
jobs:
  call:
    permissions:
      contents: read
      issues: write
    uses: OWNER/agent-issue-ops/.github/workflows/agent.reusable.yml@main
    with:
      role: explorer
      trigger_phrase: "@agent-explorer"
    secrets: inherit
```

Create `templates/agent-grill.yml` (identical except name/role/trigger):

```yaml
name: agent-grill
on:
  issues:
    types: [opened, edited]
  issue_comment:
    types: [created]
jobs:
  call:
    permissions:
      contents: read
      issues: write
    uses: OWNER/agent-issue-ops/.github/workflows/agent.reusable.yml@main
    with:
      role: grill
      trigger_phrase: "@agent-grill"
    secrets: inherit
```

Create `templates/agent-fix.yml` (write permissions):

```yaml
name: agent-fix
on:
  issues:
    types: [opened, edited]
  issue_comment:
    types: [created]
jobs:
  call:
    permissions:
      contents: write
      pull-requests: write
      issues: write
    uses: OWNER/agent-issue-ops/.github/workflows/agent.reusable.yml@main
    with:
      role: fix
      trigger_phrase: "@agent-fix"
    secrets: inherit
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash scripts/checks.sh`
Expected: `checks: OK`

- [ ] **Step 5: Commit**

```bash
git add templates/ scripts/checks.sh
git commit -m "feat: per-agent caller templates with least-privilege permissions"
```

---

### Task 5: Bootstrap script + README

**Files:**
- Create: `bootstrap.sh`
- Create: `README.md`
- Modify: `scripts/checks.sh` (shellcheck bootstrap if available)

**Interfaces:**
- Consumes: `templates/*.yml`, the `OWNER` placeholder.
- Produces: `bootstrap.sh <repo...>` (or `--all`) that installs the 3 callers + sets the `CLAUDE_CODE_OAUTH_TOKEN` secret per repo; `--dry-run` prints actions without performing them.

- [ ] **Step 1: Add the failing dry-run assertion**

Add before the final `echo "checks: OK"`:

```bash
# Bootstrap exists, is executable, supports --dry-run.
[ -x bootstrap.sh ] || fail "bootstrap.sh missing or not executable"
grep -q "dry-run" bootstrap.sh || fail "bootstrap.sh must support --dry-run"
grep -q "gh label create do-first" bootstrap.sh || fail "bootstrap.sh must create the do-first label"
command -v shellcheck >/dev/null && { shellcheck bootstrap.sh scripts/checks.sh || fail "shellcheck"; }
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/checks.sh`
Expected: FAIL with `CHECK FAIL: bootstrap.sh missing or not executable`

- [ ] **Step 3: Write `bootstrap.sh`**

Create `bootstrap.sh`:

```bash
#!/usr/bin/env bash
# Install the agent caller workflows + OAuth secret into target repos.
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
```

- [ ] **Step 4: Write `README.md`**

Create `README.md`:

```markdown
# agent-issue-ops

Mention-triggered GitHub issue agents that run the Pocock protocol on GitHub Actions,
authenticated with a Claude Max OAuth token.

## Agents
- `@agent-explorer` — read-only: explores the repo, posts a compacted brief + recommends `@agent-fix` or `@agent-grill`.
- `@agent-fix` — TDD implement → opens a single-branch PR (never merges).
- `@agent-grill` — posts sharpening questions; no code.

Handoff is human-gated: an agent recommends the next; you @mention it to proceed.

## One-time setup
1. Generate the token from the Claude account with the most usage headroom:
   `claude setup-token` → copy the token.
2. Export it locally: `export CLAUDE_CODE_OAUTH_TOKEN=<token>`
3. Make this repo public (no secrets here), or enable Settings → Actions →
   "Accessible from repositories owned by <you>".
4. Roll out to repos:
   - Dry run: `./bootstrap.sh --dry-run --all`
   - Apply:   `./bootstrap.sh --all`   (or list specific `owner/repo`s)

## Usage
On any issue, comment `@agent-explorer`. Read its brief. Reply `@agent-fix` or
`@agent-grill`. Review + merge the PR that `@agent-fix` opens.
```

- [ ] **Step 5: Verify and commit**

Run: `chmod +x bootstrap.sh && bash scripts/checks.sh`
Expected: `checks: OK`

```bash
git add bootstrap.sh README.md scripts/checks.sh
git commit -m "feat: all-repos bootstrap script + README"
```

---

### Task 6: Live end-to-end validation on inbox-cockpit

**Files:** none (integration validation — this is the real acceptance test that unit checks cannot cover).

**Interfaces:**
- Consumes: everything above, pushed to `OWNER/agent-issue-ops` (public) on `main`.

- [ ] **Step 1: Publish this repo**

```bash
gh repo create agent-issue-ops --public --source=. --remote=origin --push
```

- [ ] **Step 2: Generate + store the token, install on inbox-cockpit only**

```bash
claude setup-token            # copy output
export CLAUDE_CODE_OAUTH_TOKEN=<token>
./bootstrap.sh --dry-run <owner>/inbox-cockpit   # inspect
./bootstrap.sh <owner>/inbox-cockpit
```

Verify the ordering label landed:
`gh label list -R <owner>/inbox-cockpit | grep do-first` → expected: one match.

- [ ] **Step 3: Explorer round-trip (read-only)**

On inbox-cockpit issue #2 (the develop-button ticket), comment `@agent-explorer`.
Expected: within a few minutes a comment appears with a compacted brief + a named
recommendation (`@agent-fix` or `@agent-grill`). Verify **no** branch/PR was created.

- [ ] **Step 4: Fix round-trip (PR-only)**

Reply `@agent-fix` on a small, well-scoped issue.
Expected: a new branch + one PR linking the issue; tests run in the PR; **no auto-merge**.

- [ ] **Step 5: Grill round-trip**

On a deliberately vague issue, comment `@agent-grill`.
Expected: a comment with sharpening questions; no code change.

- [ ] **Step 6: Token-decouple check**

Log out of the Claude account locally, re-trigger `@agent-explorer` on an issue.
Expected: the Action still runs (proves the secret is independent of local login).

- [ ] **Step 7: Roll out to all repos**

```bash
./bootstrap.sh --dry-run --all   # review
./bootstrap.sh --all
```

Expected: each repo gets the three workflows + the secret; `--dry-run` matches.

---

## Notes for the executor
- The reusable workflow uses a multiline `$GITHUB_ENV` heredoc to pass the selected prompt into the action's `prompt` input — keep the `PROMPT_EOF` delimiter unique and unquoted content out of the prompt bodies.
- Least-privilege is enforced by the **caller** `permissions:` blocks, not the reusable workflow — do not add `pull-requests: write` to the explorer/grill templates.
- `claude-code-action@v1` auto-detects mode from the event; `trigger_phrase` gates activation, so multiple workflows in one repo coexist without firing each other.

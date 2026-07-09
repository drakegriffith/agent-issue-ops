# agent-issue-ops

Mention-triggered GitHub issue agents that run the Pocock protocol on GitHub Actions,
authenticated with a Claude Max OAuth token.

## Agents
- `@agent-explorer` — read-only: explores the repo, posts a compacted brief + recommends `@agent-fix` or `@agent-grill`. Applies the `do-first` label to prerequisite issues.
- `@agent-fix` — TDD implement → opens a single-branch PR (never merges).
- `@agent-grill` — posts sharpening questions; no code.

Handoff is human-gated: an agent recommends the next; you @mention it to proceed.

## Label taxonomy
`bootstrap.sh` installs the **agent-issue-ops standard taxonomy** into every target repo
(idempotent `gh label create --force`), so a color always means one thing across all repos.
The traffic-light hues (red / orange / yellow / green) are **reserved for priority only**.

| Group | Labels |
|---|---|
| **Priority** (exactly one) | `P0-critical` 🔴 · `P1-high` 🟠 · `P2-medium` 🟡 · `P3-low` 🟢 |
| **Type** (as they apply) | `safety` · `bug` · `code-quality` · `spec-gap` · `enhancement` · `docs` |
| **Workflow** (state) | `epic` · `blocked` · `do-first` |
| **Area/subsystem** | ad-hoc, always blue `0969da` (e.g. `publish-queue`) |

**Ordering:** most issues are order-independent and carry no workflow label. An issue that
must be done before others (e.g. a gating grill-me) gets **`do-first`** — the explorer applies
it when it judges the issue gates dependent work. Its dependents get **`blocked`** with a
`> ⛔ Blocked by #N` first body line. (`do-first` is a neutral charcoal, off the reserved
traffic-light hues, so it never reads as a priority.)

## One-time setup
1. Generate the token from the Claude account with the most usage headroom:
   `claude setup-token` → copy the token.
2. Export it locally: `export CLAUDE_CODE_OAUTH_TOKEN=<token>`
3. Make this repo **public** (no secrets here), or enable Settings → Actions →
   "Accessible from repositories owned by <you>" so other repos can call the reusable workflow.
4. Roll out to repos:
   - Dry run: `./bootstrap.sh --dry-run --all`
   - Apply:   `./bootstrap.sh --all`   (or list specific `owner/repo`s)

## Usage
On any issue, comment `@agent-explorer`. Read its brief. Reply `@agent-fix` or
`@agent-grill`. Review + merge the PR that `@agent-fix` opens.

## Development
`bash scripts/checks.sh` validates the workflows, templates, and bootstrap offline
(YAML validity, role markers, least-privilege permissions, label creation).

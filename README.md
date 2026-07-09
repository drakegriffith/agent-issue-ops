# agent-issue-ops

Mention-triggered GitHub issue agents that run the Pocock protocol on GitHub Actions,
authenticated with a Claude Max OAuth token.

## Agents
- `@agent-explorer` — read-only: explores the repo, posts a compacted brief + recommends `@agent-fix` or `@agent-grill`. Applies the `do-first` label to prerequisite issues.
- `@agent-fix` — TDD implement → opens a single-branch PR (never merges).
- `@agent-grill` — posts sharpening questions; no code.

Handoff is human-gated: an agent recommends the next; you @mention it to proceed.

## Ordering
Most issues are order-independent and carry no label. An issue that must be done before
others (e.g. a gating grill-me) gets the **`do-first`** label — visible in the issue list.
The explorer applies it when it judges the issue gates dependent work.

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

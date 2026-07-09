# agent-issue-ops

Mention-triggered GitHub issue agents that run the Pocock protocol on GitHub Actions.

**Engine: OpenAI Codex (GPT) — enforced.** All three agents run through
`openai/codex-action@v1` on the ChatGPT Pro plan (no API key). The engine is
hardcoded in `agent.reusable.yml`; there is no per-run model choice. Runs draw
from the plan's rolling usage window, and Codex executes in a `workspace-write`
sandbox (network on, sudo dropped) with each role's least-privilege
`GITHUB_TOKEN` doing the real permission enforcement.

## Agents
- `@agent-explorer` — read-only: explores the repo, posts a compacted brief + recommends `@agent-fix` or `@agent-grill`. Applies the `do-first` label to prerequisite issues.
- `@agent-fix` — TDD implement → opens a single-branch PR (never merges).
- `@agent-grill` — posts sharpening questions; no code.

Handoff is human-gated: an agent recommends the next; you @mention it to proceed.

## Ordering
Most issues are order-independent and carry no label. An issue that must be done before
others (e.g. a gating grill-me) gets the **`do-first`** label — visible in the issue list.
The explorer applies it when it judges the issue gates dependent work.

## Label kit (standard issue-label taxonomy)
[`label-kit/`](label-kit/) carries the standard label taxonomy for every repo:
traffic-light priority `P0-critical`…`P3-low` (red/orange/yellow/green reserved for
priority only) plus type (`bug`, `safety`, `spec-gap`, …) and workflow (`epic`,
`blocked`) labels. Works on any repository, any project.
- Apply to a repo: `bash label-kit/setup-labels.sh [owner/repo]` (idempotent).
- Install as a local Claude skill: `bash label-kit/install.sh`.
- Onboarding + the shared issue workflow: `label-kit/references/agent-workflow.md`.

## One-time setup
1. Store your Codex login as a file so bootstrap can read it: add
   `cli_auth_credentials_store = "file"` to `~/.codex/config.toml`, then `codex login`
   with the ChatGPT account that has the most usage headroom.
2. Make this repo **public** (no secrets here), or enable Settings → Actions →
   "Accessible from repositories owned by <you>" so other repos can call the reusable workflow.
3. Roll out to repos (installs workflows + sets the `CODEX_AUTH_JSON` secret + label):
   - Dry run: `./bootstrap.sh --dry-run --all`
   - Apply:   `./bootstrap.sh --all`   (or list specific `owner/repo`s)

## Auth going stale
CI seeds `auth.json` fresh from the repo secret on every run and discards any
refreshed tokens afterwards. If agent runs start failing auth, reseed from your
(still fresh) local login: `codex login` if needed, then re-run `./bootstrap.sh --all`.

## Usage
On any issue, comment `@agent-explorer`. Read its brief. Reply `@agent-fix` or
`@agent-grill`. Review + merge the PR that `@agent-fix` opens.

## Development
`bash scripts/checks.sh` validates the workflows, templates, and bootstrap offline
(YAML validity, role markers, least-privilege permissions, label creation).

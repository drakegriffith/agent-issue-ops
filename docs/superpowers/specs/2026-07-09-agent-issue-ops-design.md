---
date: 2026-07-09
status: approved-design
topic: agent-issue-ops
tags: [github-actions, claude-code-action, pocock, issue-ops, agents]
---

# Agent Issue-Ops — mention-driven GitHub issue agents

## Problem & goal

Turn GitHub issues into a work queue driven by **named agents you invoke by @mention**. You
assign/@mention an agent on an issue; it runs on GitHub Actions (on your Claude Max subscription),
does its stage of the **Matt Pocock protocol**, and reports back in the issue thread. The headline
flow: an **explorer** gathers + compacts repo context and recommends the next move; you then
@mention the recommended agent (**fix** or **grill**) to advance. Nothing runs autonomously without
your mention, and code changes only ever arrive as a **PR you merge**.

## Non-goals

- No auto-merge. Ever. `@agent-fix` opens a PR; a human merges.
- No always-decide AI router. The explorer *recommends*; the human *advances* (fail-closed).
- No stacked/multi-branch topologies. `@agent-fix` uses a single branch → one PR.
- No dependence on locally-installed skills. The cloud runner is self-contained.
- v1 does not build `@agent-spec` (design-doc stage) — deferred; see Open questions.

## Users & interaction

Solo (Drake). Interaction is entirely through the GitHub issue UI:

1. Open an issue (or use an existing one).
2. @mention `@agent-explorer` in the issue body or a comment.
3. Read the explorer's posted **brief + recommendation**.
4. Reply `@agent-fix` or `@agent-grill` to advance.
5. For fixes: review the PR it opens, merge if good.

## Architecture

**Runtime:** GitHub Actions using `anthropics/claude-code-action`. **Auth:** a long-lived
`CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, stored as a GitHub Actions secret. This is
decoupled from local login state — logging in/out of Claude accounts on the Mac has no effect. Runs
count against the account whose token was used, so the token is generated from the account with the
most usage headroom.

**Named agents = distinct trigger phrases.** The stock action responds to one `@claude`. To get
multiple named agents, we run **one reusable workflow** with **three thin caller workflows**, each
setting a different `trigger_phrase` and passing a different `role` input:

```
.github/workflows/agent-explorer.yml   trigger: "@agent-explorer"  role: explorer
.github/workflows/agent-fix.yml        trigger: "@agent-fix"       role: fix
.github/workflows/agent-grill.yml      trigger: "@agent-grill"     role: grill
        │
        └── uses: drakegriffith/agent-issue-ops/.github/workflows/agent.reusable.yml@main
             (holds the claude-code-action step + per-role prompt selection)
```

**The issue thread is the shared memory.** Each Action run is stateless. The explorer's compacted
brief is posted as an issue comment; when `@agent-fix` later runs, it reads the issue + comments
(including that brief) as its context. That comment *is* the compaction handoff.

## The three agents

| Agent | Trigger | Does | Guardrail |
|---|---|---|---|
| `@agent-explorer` | `@agent-explorer` | Explore repo + issue → compact into a tight brief → post it as a comment → recommend `@agent-fix` **or** `@agent-grill` with a one-line reason | **Read-only.** No commits, no branch, no PR. |
| `@agent-fix` | `@agent-fix` | Read issue + explorer brief → Pocock `implement` (TDD red→green) → self-review the diff (standards + spec) → open a **single-branch PR** proposing merge to main | **PR only; never merges.** One branch. |
| `@agent-grill` | `@agent-grill` | Run a grill-me Q&A in the issue thread to sharpen an under-scoped issue, then recommend `@agent-fix` | Scoping only; no code edits. |

Each role is a **~30-line prompt** that inlines the relevant Pocock stage. `pocock-code-review` runs
*inside* `@agent-fix` (before it opens the PR), not as a separate agent.

## Label vocabulary (ordering)

Most issues are minor, order-independent bug fixes and carry **no special label**. For the case where
one issue must be resolved *before* others — typically a large `@agent-grill` that gates dependent
work — there is one visible label:

- **`do-first`** — a prerequisite/blocker: complete this issue before starting dependent ones. Shows
  up in the GitHub issue list so ordering is obvious at a glance.

`@agent-explorer` **applies `do-first`** (it has `issues: write`, and labelling is issue metadata, not
a code change) when its exploration concludes the issue gates others, and calls that out in its brief.
The human can add/remove the label manually too. The label is created per repo by `bootstrap.sh`
(`gh label create`). Optional future extension: a `blocked` label for the dependent issues — deferred;
`do-first` alone gives the ordering signal Drake asked for.

## Protocol delivery (skills on the runner)

The cloud runner does **not** have `~/.claude/skills`. v1 encodes each Pocock stage **inline in the
role prompt** — faithful because the skills are themselves markdown prompts. Future fidelity upgrade
(optional): a workflow step installs the Pocock skills as a plugin so prompts can invoke them
verbatim. Tracked as an enhancement, not v1 scope.

## Guardrails / autonomy bounds

- Explorer is **read-only** — enforced by prompt + by giving that workflow no write path to code
  (it only comments).
- Fix is **PR-only** — never runs `gh pr merge`; branch → PR → human merge.
- Advancement is **human-gated** — an agent only runs when *you* @mention it. The explorer names the
  next agent but does not summon it.

## Rollout to all repos

Target is all of Drake's repos, because the @mention itself is the opt-in gate (nothing runs
unless mentioned), so watching everything creates no noise.

GitHub has no native "apply to every repo." Each repo needs, one-time (scripted):

1. Three caller workflow files (`.github/workflows/agent-*.yml`) — 3 lines each, pointing at the
   central reusable workflow.
2. The `CLAUDE_CODE_OAUTH_TOKEN` secret (personal account → per-repo secret via `gh secret set`).

A **bootstrap script** (`bootstrap.sh`, a `gh repo list` → loop) installs both across all repos in
one command. **Validation-first:** build + prove end-to-end on `inbox-cockpit` (which already has
issues #2/#3), then run the bootstrap for the rest.

## Reused vs new

| Reused | New (the build) |
|---|---|
| `anthropics/claude-code-action`; Claude GitHub app | `agent.reusable.yml` + 3 caller workflows |
| Pocock protocol (inlined into prompts) | 3 role prompts (`explorer`, `fix`, `grill`) |
| Your OAuth-token / Max-sub pattern | `bootstrap.sh` (gh loop: workflows + secret) |
| `pocock-code-review` (folded into fix) | — |

## Open questions / deferred

- **`@agent-spec`** (write a design doc for large issues) — deferred to v2; explorer can still
  recommend "this needs a spec" in prose meanwhile.
- **Plugin-based skill fidelity** vs inline prompts — v1 inline; revisit if prompts drift from the
  real skills.
- **Repo home** — this spec lives in a new dedicated repo `agent-issue-ops` (holds reusable
  workflow + role prompts + bootstrap). Confirm before publishing to GitHub.

## Acceptance criteria (DoD)

1. On `inbox-cockpit`, @mentioning `@agent-explorer` on an issue posts a compacted brief + a named
   recommendation, and makes no code changes.
2. Replying `@agent-fix` produces a single-branch PR (TDD + self-review) that does not auto-merge.
3. Replying `@agent-grill` posts sharpening questions in-thread and makes no code changes.
4. The OAuth-token secret survives a local Claude logout/login (Action still runs).
5. `bootstrap.sh` installs the three callers + secret across all listed repos idempotently.

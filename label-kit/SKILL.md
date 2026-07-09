---
name: gh-label-kit
description: Apply the agent-issue-ops standard GitHub issue-label taxonomy (priority traffic-light P0–P3 + type + workflow labels) to any repo, and explain the shared agent issue workflow. Use when asked to "set up our labels", "apply the labeling structure", "use the label taxonomy we created", "label these issues", or when opening issues that need consistent priority / blocking labels.
---

# GitHub Label Kit — agent-issue-ops standard

One label taxonomy for **every** repo. Traffic-light **priority** (🔴🟠🟡🟢) is reserved;
**type** and **workflow** labels use other hues, so a color always means one thing.

## Apply the taxonomy to a repo

Run the script that ships next to this file (idempotent — safe to re-run):

```
bash setup-labels.sh            # labels the current repo
bash setup-labels.sh owner/repo # or a named repo
```

Requires the GitHub CLI authenticated (`gh auth login`). Full spec + hex colors:
`references/label-taxonomy.md`.

## Labeling rules (apply on every issue)

- **Exactly one** priority: `P0-critical` · `P1-high` · `P2-medium` · `P3-low`.
- **Type** labels as they apply: `safety`, `bug`, `code-quality`, `spec-gap`, `enhancement`, `docs`.
- **Dependency** → tag the dependent with `blocked` AND make the first body line `> ⛔ Blocked by #N — do it first.`; tag the prerequisite that gates it with `do-first`.
- **Tracking issue** → `epic`, with a `- [ ] #N — title` checklist grouped by priority (auto-ticks as children close).
- **Subsystem** → an area label (e.g. `publish-queue`), blue `0969da`, created ad-hoc.

## Creating issues from a code review

When filing findings (e.g. from `pocock-code-review`), one issue per finding:
title `[area] short description`, body = axis + severity + `file:line` evidence + a one-line fix, plus
the labels above. Then a single `epic` issue links them all as the one link to hand a human.

## The shared agent workflow

How two people + their terminals (Claude Code, Codex) stay in sync — review → tickets → labels → fix —
and how to onboard a teammate: `references/agent-workflow.md`. Share that file directly.

# Label Taxonomy — agent-issue-ops standard

One taxonomy for **every** repo. The rule that makes it readable at a glance:
**the traffic-light hues (red / orange / yellow / green) are reserved for _priority only_.**
Every other label uses a different color, so a color never means two things.

Apply it to any repo:  `bash setup-labels.sh [owner/repo]`  (idempotent).

## 1. Priority — exactly one per issue (traffic light 🔴🟠🟡🟢)

| Label | Color | Hex | Meaning |
|---|---|---|---|
| `P0-critical` | 🔴 red | `d73a4a` | Drop everything — safety / data-loss / security; something can leak past a guardrail |
| `P1-high` | 🟠 orange | `f66a0a` | Integrity / correctness risk |
| `P2-medium` | 🟡 yellow | `ffd33d` | Normal correctness / operator-facing |
| `P3-low` | 🟢 green | `2da44e` | Refactor / polish / governance |

## 2. Type — add as many as apply (non-traffic hues)

| Label | Color | Hex | Meaning |
|---|---|---|---|
| `safety` | pink | `bf3989` | Fail-open / no-autosend / guardrail correctness |
| `bug` | magenta | `d876e3` | Defect — wrong behavior |
| `code-quality` | teal | `1b7c83` | Refactor / smell / maintainability |
| `spec-gap` | purple | `8250df` | Diverges from the spec / requirements |
| `enhancement` | cyan | `a2eeef` | New capability |
| `docs` | blue | `0969da` | Documentation / notes |

## 3. Workflow — state, not kind

| Label | Color | Hex | Meaning |
|---|---|---|---|
| `epic` | black | `24292f` | Tracking issue — body has a `- [ ] #N — title` checklist grouped by priority |
| `blocked` | gray | `6e7781` | Has a hard prerequisite — **first line of the body** is `> ⛔ Blocked by #N` |
| `do-first` | charcoal | `444d56` | The prerequisite that gates others — do it before its dependents; pairs with `blocked` |

## 4. Area / subsystem — created ad-hoc

One per subsystem you're tracking (e.g. `publish-queue`, `billing`, `auth`). Always **blue `0969da`**
so area labels read as a distinct family:

```
gh label create publish-queue -R <owner/repo> --color 0969da --description "Publish Queue subsystem"
```

## Conventions

- **Every issue** carries exactly one `P0`–`P3`, plus any `type` labels, plus its area label.
- **Blocking:** add the `blocked` label AND make the first body line `> ⛔ Blocked by #4, #5 — do them first.`
  Labels show the ordering; they don't *enforce* it (GitHub won't stop you). For hard enforcement use
  GitHub's native "Blocked by" issue relationships or a Project board.
- **Epics:** the tracking issue lists children as a grouped checklist so it ticks off automatically as
  each child closes.
- **Colors are native GitHub** — visible as pills on the issue list, inside each issue, and on the repo's
  `/labels` page (which shows every color + description). No extension or MCP needed.

# Working with the Agents — a 5-minute onboarding

For Drake **and** the co-founder. This is how our terminals (Claude Code / Codex) and our GitHub
issues stay in sync across machines, so "push → pull → run stuff" just works.

## The mental model

- **The repo is the spec.** Every repo has an `AGENTS.md` (Codex + other agents read it) and a
  `CLAUDE.md` (Claude Code reads it). They're twins — the same rules, same verify command. Read that
  file first; it tells the agent how to build and how to check "done."
- **Issues are the work-list.** Findings and TODOs become GitHub issues with a **consistent label
  taxonomy** (see `label-taxonomy.md`) so priority and blockers read at a glance on any repo.
- **Skills are shared muscle memory.** A "skill" is a folder of instructions an agent auto-invokes.
  If we both install the same skills, we both get the same behavior. This kit is one such skill.

## One-time setup (each machine)

1. Install the GitHub CLI and sign in: `gh auth login` (pick your own GitHub account).
2. From a fresh pull of the repo, install the shared kit as a skill:
   ```
   bash label-kit/install.sh
   ```
   That copies the kit into `~/.claude/skills/gh-label-kit/`, so it's available in **every** repo you
   open — not just this one.

## Daily use

- **Apply our labels to a repo** (new repo, or to sync an old one):
  say to your terminal *"apply our label structure"* → the `gh-label-kit` skill runs `setup-labels.sh`.
  Or just run `bash ~/.claude/skills/gh-label-kit/setup-labels.sh` yourself.
- **Read the labels:** a repo's `/labels` page is the legend (color + description). On the issue list,
  🔴/🟠/🟡/🟢 = priority; other colors = type/workflow. Filter the board with e.g.
  `label:P0-critical` or `label:<area> label:P0-critical`.
- **Order of work:** do `P0` before `P1` before `P2` before `P3`. If an issue has the `blocked` label,
  its first body line names the issue(s) to finish first (`⛔ Blocked by #N`).
- **Close an issue from a fix:** put `Closes #N` (or `Fixes #N`) in the commit or PR — GitHub links the
  code and auto-closes the issue when it merges to the default branch.

## How we collaborate

- Drake reviews / opens issues + labels them → pushes the branch.
- Co-founder pulls → `AGENTS.md`/`CLAUDE.md` orient his terminal identically → he picks up issues by
  priority, fixes them test-first, and references `Closes #N` in his commits.
- Because we share this kit, an issue labeled `P0-critical` / `blocked` means the exact same thing on
  both our screens. No one has to ask "what does this label mean?"

## Where the pieces live

| Piece | Path | Purpose |
|---|---|---|
| Label taxonomy | `label-kit/references/label-taxonomy.md` | the standard + hex colors |
| Apply-labels script | `label-kit/setup-labels.sh` | idempotent `gh label` bootstrap |
| Install the skill | `label-kit/install.sh` | copy kit → `~/.claude/skills/` |
| Agent router | `AGENTS.md` / `CLAUDE.md` (repo root) | how the agent behaves in this repo |

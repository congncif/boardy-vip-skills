<!-- Created by claude-haiku-4-5 on 2026-05-19 -->

# Architecture Decision Records (ADRs)

> **Purpose**: capture *why* the project is built a certain way — non-obvious choices, deliberate deviations from the standard convention, and trade-offs made at a point in time.
>
> **What belongs here**: structural decisions that future maintainers (human or AI) will second-guess if they don't know the reasoning. Examples: why a module skips a standard target, why bindings live at a non-default path, why Module X was split from Module Y.
>
> **What does NOT belong here**: ephemeral task notes, code-change rationale (use commit messages), bug postmortems (use a separate location), or rules already encoded in `PROJECT_STRUCTURE.md` / `CLAUDE.md`.

---

## Format

ADRs use the Michael Nygard format:

```markdown
<!-- Created by <ai-or-author> on <YYYY-MM-DD> -->

# ADR-NNNN: <title>

- Status: Proposed | Accepted | Superseded by ADR-XXXX | Deprecated
- Date: YYYY-MM-DD
- Deciders: <names or roles>

## Context

The forces at play: what's the problem, what constraints exist, what alternatives were considered.

## Decision

The choice we made, stated clearly.

## Consequences

What becomes easier, what becomes harder, what trade-offs we accept.
Optional sub-headings: **Positive**, **Negative**, **Neutral**.

## Alternatives Considered

(Optional but recommended.) Other options and why they were rejected.
```

---

## Naming

- File: `NNNN-kebab-case-title.md` where NNNN is the next sequential 4-digit number.
- Once an ADR is **Accepted**, do not rewrite it. To change a decision, write a new ADR with status `Supersedes ADR-NNNN`, and update the old ADR's status to `Superseded by ADR-MMMM`.

---

## Index

| ID | Title | Status | Date |
|----|-------|--------|------|
| _add rows as ADRs are written_ | | | |

When adding a new ADR, append a row here.

---

## When to write an ADR

Write one before merging if any of these apply:

- A module deviates from the standard convention in `PROJECT_STRUCTURE.md`.
- A new category of module is introduced.
- A cross-cutting rule (naming, dependency direction, composition root) changes.
- An ambiguous trade-off was resolved (perf vs simplicity, SDK-A vs SDK-B, etc.) and is likely to be re-litigated.

Skip ADRs for: routine feature work, bug fixes, code-style preferences, ephemeral experiments.

# Modern Large-Scale App Constitution

This file is the governing constitution for AI work in this project.
Detailed architecture, framework patterns, code skeletons, and project bindings live in referenced documents.

---

## 1. Manifesto

We build modern large-scale apps as modular systems of explicit capabilities.

Each capability has a stable interface, a clear owner, and a bounded implementation. Runtime composition is explicit. Domain policy remains pure. Presentation remains humble. Infrastructure stays at the edge. Cross-boundary communication happens through contracts, not shortcuts.

Default behavior: preserve the model, make the smallest correct change, and verify it with real signals.

---

## 2. Constitutional Principles

1. **SDK-first** — prefer platform and language-standard capabilities before third-party dependencies.
2. **Interface before implementation** — consumers depend on public contracts, not concrete internals.
3. **Explicit composition** — application assembly happens at defined composition roots.
4. **Capabilities as services** — feature entry points are activatable capabilities behind stable contracts.
5. **Domain-driven layering** — domain policy is pure; application behavior coordinates use cases; infrastructure adapts external systems.
6. **Unidirectional presentation flow** — user intent, business behavior, presentation mapping, and rendering each have a single direction and owner.
7. **State ownership is explicit** — transient session state belongs to the session owner, not shared coordination shells.
8. **Communication is contractual** — boundary crossings use interfaces, delegates, buses, destinations, or documented contracts.
9. **Composition roots wire concretes** — concrete initializers and infrastructure types assembled only at explicit outer-layer composition points.
10. **Verification is part of design** — a change is incomplete until its correctness signal is observed and reported.

---

## 3. Mandatory Load Order

Before generating or reviewing code:

1. Load `@.claude/rules/QUICK_REF.md` first.
2. Resolve project-wide configuration from `@.claude/rules/PROJECT_CONFIG.md`.
3. Resolve current topology from `@.claude/rules/PROJECT_STRUCTURE.md` when module/scheme ownership matters.
4. Load the task-specific spec from the `@.claude/rules/QUICK_REF.md` routing table.
5. Load `@.claude/rules/REVIEWER_CHECKLIST.md` only for code review tasks.
6. Load `@.claude/rules/EXAMPLES.md`, then exactly one matching `EXAMPLES_*.md` file only when a code skeleton is needed.

---

## 4. Rule Hierarchy

When instructions conflict:

1. User's explicit current instruction.
2. This constitution.
3. `@.claude/rules/QUICK_REF.md` and task-specific specs.
4. `@.claude/rules/REVIEWER_CHECKLIST.md` for review tasks.
5. `@.claude/rules/PROJECT_CONFIG.md` for project-wide configuration.
6. `@.claude/rules/PROJECT_STRUCTURE.md` for current topology.
7. `@.claude/rules/EXAMPLES.md` and one matching example file for code skeletons.
8. Existing code patterns in the target module.

---

## 5. Non-Negotiable Boundaries

1. Public contracts and private implementations remain separated.
2. Cross-module dependencies use public interfaces only.
3. Presentation objects render and forward; they do not own business policy.
4. Domain objects stay pure and framework-neutral.
5. Mapping from domain data to display data has one owner (Presenter).
6. Coordination shells stay stateless unless a spec explicitly defines the session owner.
7. Cross-boundary communication uses documented mechanisms, never hidden object retrieval.
8. Lifecycle completion and resource release follow the task-specific lifecycle spec.
9. Concrete dependencies wired at composition roots; inner layers depend on protocols/contracts.
10. Any exception must be explicit, local, justified.

---

## 6. Operating Discipline

- Use `@.claude/rules/PROJECT_CONFIG.md` for build/test/debug commands.
- Use `@.claude/rules/PROJECT_STRUCTURE.md` for current module/scheme ownership.
- Treat empty or ambiguous verification output as failure.
- Store AI workflow artifacts only under `.superpowers/`.
- Stage commits by explicit reviewed file paths only. Never `git add -A` unless explicitly approved.
- Commit or push only after user approval for the current phase.

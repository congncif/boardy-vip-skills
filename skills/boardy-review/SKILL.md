---
name: boardy-review
description: Use when reviewing a pull request or verifying implementation on a Boardy+VIP project — loads the full architecture compliance checklist from the bundled spec
version: 1.1.2
---

# Boardy+VIP Code Review

Load the full checklist from the bundled spec, then apply every item to the PR:

```
Read ~/.claude/skills/boardy-vip/specs/REVIEWER_CHECKLIST.md
```

## How to Apply

Work through each section in order:

1. **Architecture Rules** — check every PR regardless of scope
2. **Per-Activation Resources** — check boards wrapping external services (SDKs, sockets)
3. **Activation Barrier** — check boards that declare `activationBarrier` or are used as a barrier
4. **Extensible Provider** — check modules with multiple concrete provider backends
5. **Module Structure** — check podspecs, folder layout, pod install
6. **IO Layer** — check BoardIDs, access modifiers, ServiceMap extensions
7. **VIP Components** — check Board, Interactor, Presenter, ViewController, Builder
8. **Service Layer** — check Domain models, UseCases, Repositories, Infra
9. **Context Navigation** — check every PR that has navigation or alert code

## Quick Fails (stop review immediately)

Any of these = reject without reading further:

- `public` keyword inside `Sources/` files
- Import of `{Module}Plugins` from another module
- `registerFlows()` called inside `activate()`
- ViewModel constructed in Interactor
- Business logic inside ViewController
- Board stores per-activation service as property
- `public enum {Feature}ProviderConfiguration` (enum form of provider config)

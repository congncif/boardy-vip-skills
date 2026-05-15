<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# Boardy+VIP Rules Pack

Generic design and execution standards for modular iOS apps built with Boardy, VIP, plugin composition, and domain-driven layering.

---

## Five Pillars

| # | Pillar | Rule home |
|---|--------|-----------|
| 1 | SDK-first | `.claude/rules/SDK_FIRST.md` |
| 2 | Modular + Interface Module | `.claude/rules/MODULE_CREATION.md`, `.claude/rules/IO_INTERFACE.md` |
| 3 | Plugin Architecture | `.claude/rules/PLUGINS_INTEGRATION.md` |
| 4 | Micro-services Composable | `.claude/rules/MICROBOARD_UI.md`, `.claude/rules/MICROBOARD_NONUI.md`, `.claude/rules/COMMUNICATION.md`, `.claude/rules/COMPOSABLE_BOARD.md` |
| 5 | Domain-driven Layered | `.claude/rules/ARCHITECTURE.md`, `.claude/rules/LAYERING.md`, `.claude/rules/SERVICE_LAYER.md`, `.claude/rules/VIP_COMPONENTS.md` |

---

## Quick Start

1. Copy `.claude/rules/` and `@.claude/agents/` into the target project.
2. Fill `.claude/rules/PROJECT_CONFIG.md` with project-specific values: workspace, scheme, simulator, module root, base branch, app entry file.
3. Ensure project `@CLAUDE.md` says: load `.claude/rules/QUICK_REF.md` first, then task-specific specs.
4. Use `.claude/rules/ADOPTION.md` as the migration checklist.
5. Keep project-specific examples out of generic rule files; place them in `.claude/rules/PROJECT_CONFIG.md`, project `@CLAUDE.md`, or feature PRDs.

---

## Task Routing

| I want to... | Load |
|--------------|------|
| Understand architecture | `.claude/rules/QUICK_REF.md` → `.claude/rules/ARCHITECTURE.md` |
| Choose or add a dependency | `.claude/rules/QUICK_REF.md` → `.claude/rules/SDK_FIRST.md` |
| Create a module | `.claude/rules/QUICK_REF.md` → `.claude/rules/MODULE_CREATION.md` → `.claude/rules/IO_INTERFACE.md` |
| Define public board IO | `.claude/rules/QUICK_REF.md` → `.claude/rules/IO_INTERFACE.md` |
| Build a UI board | `.claude/rules/QUICK_REF.md` → `.claude/rules/MICROBOARD_UI.md` → `.claude/rules/VIP_COMPONENTS.md` |
| Build a non-UI board | `.claude/rules/QUICK_REF.md` → `.claude/rules/MICROBOARD_NONUI.md` |
| Wire board communication | `.claude/rules/QUICK_REF.md` → `.claude/rules/COMMUNICATION.md` |
| Add plugin integration | `.claude/rules/QUICK_REF.md` → `.claude/rules/PLUGINS_INTEGRATION.md` |
| Share service across modules | `.claude/rules/QUICK_REF.md` → `.claude/rules/CROSS_MODULE_DI.md` |
| Implement service layer | `.claude/rules/QUICK_REF.md` → `.claude/rules/SERVICE_LAYER.md` → `.claude/rules/LAYERING.md` |
| Write tests | `.claude/rules/QUICK_REF.md` → `.claude/rules/TESTING.md` |
| Review code | `.claude/rules/QUICK_REF.md` → `.claude/rules/REVIEWER_CHECKLIST.md` |
| Find skeleton code | `.claude/rules/QUICK_REF.md` → `.claude/rules/EXAMPLES.md` → one matching `EXAMPLES_*.md` |

---

## Assumed Project Shape

The pack assumes an iOS project with:

- Module root such as `{ModuleRoot}/{ModuleName}/`.
- Interface target `{ModuleName}` containing `IO/**/*.swift`.
- Implementation target `{ModuleName}Plugins` containing `Sources/**/*.swift`.
- App-level dependency configuration such as `Podfile` or equivalent package wiring.
- Boardy `Motherboard`, `BoardProducer`, and `ServiceMap` usage.
- Plugin host that installs `LauncherPlugin`s before launch.
- Build/test commands documented outside generic specs, referenced via `.claude/rules/PROJECT_CONFIG.md`.

If your project uses different folders or package tooling, update `.claude/rules/PROJECT_CONFIG.md` and project `@CLAUDE.md`; do not hard-code those values into generic rules.

---

## Terminology Map

| Canonical term | Common alias |
|----------------|--------------|
| Interface Module | IO module / public target |
| Implementation Module | Plugins module / Sources target |
| Business Application Layer | VIP layer / Microboards |
| Domain Layer | Services/Domain |
| Infrastructure Layer | Services/Infra, Tracking, concrete Builders |
| Plugin host | `PluginLauncher` |
| Service registry | `BoardProducer` |
| Service gateway | Motherboard |
| Service contract | `ActivatableBoard`, `InteractableBoard` |
| Service request | `BoardID` + Input |
| Service response | Output flow |
| Service command | Interaction command |

---

## Non-Negotiables

- Load `.claude/rules/QUICK_REF.md` first.
- Keep Interface Modules public and Implementation Modules internal.
- Consumers import Interface Modules only, never Plugins.
- Board → Controller communication uses event buses, not stored/retrieved controller references.
- `watch(content:)` is lifecycle tracking only.
- Duplicate-activation guard only when a board is explicitly single-session.
- Presenter is the only Domain → ViewModel mapper.
- Domain stays pure: no UIKit, Boardy, networking SDKs, DTOs, or vendor types.
- Concrete Builder structs are composition roots; Board depends on `Buildable` protocol only.
- Project-specific values live in `.claude/rules/PROJECT_CONFIG.md`.

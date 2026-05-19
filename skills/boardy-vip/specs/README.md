<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# Boardy+VIP Rules Pack

Generic design and execution standards for modular iOS apps built with Boardy, VIP, plugin composition, and domain-driven layering.

---

## Five Pillars

| # | Pillar | Rule home |
|---|--------|-----------|
| 1 | SDK-first | `SDK_FIRST.md` |
| 2 | Modular + Interface Module | `MODULE_CREATION.md`, `IO_INTERFACE.md` |
| 3 | Plugin Architecture | `PLUGINS_INTEGRATION.md` |
| 4 | Micro-services Composable | `MICROBOARD_UI.md`, `MICROBOARD_NONUI.md`, `COMMUNICATION.md`, `COMPOSABLE_BOARD.md` |
| 5 | Domain-driven Layered | `ARCHITECTURE.md`, `LAYERING.md`, `SERVICE_LAYER.md`, `VIP_COMPONENTS.md` |

---

## Quick Start

1. Install the skill pack once per machine (`./install.sh` from the `boardy-vip-skills` repo). Plugin specs are then read live from `~/.claude/skills/boardy-vip/specs/`; no per-project copy. Project-specific bindings live under `{ProjectConfigPath}` and `{ProjectStructurePath}`.
2. Fill `{ProjectConfigPath}` with project-specific values: workspace, scheme, simulator, module root, base branch, app entry file.
3. Ensure project `@CLAUDE.md` says: load `QUICK_REF.md` first, then task-specific specs.
4. Use `ADOPTION.md` as the migration checklist.
5. Keep project-specific examples out of generic rule files; place them in `{ProjectConfigPath}`, project `@CLAUDE.md`, or feature PRDs.

---

## Task Routing

| I want to... | Load |
|--------------|------|
| Understand architecture | `QUICK_REF.md` → `ARCHITECTURE.md` |
| Choose or add a dependency | `QUICK_REF.md` → `SDK_FIRST.md` |
| Create a module | `QUICK_REF.md` → `MODULE_CREATION.md` → `IO_INTERFACE.md` |
| Define public board IO | `QUICK_REF.md` → `IO_INTERFACE.md` |
| Build a UI board | `QUICK_REF.md` → `MICROBOARD_UI.md` → `VIP_COMPONENTS.md` |
| Build a non-UI board | `QUICK_REF.md` → `MICROBOARD_NONUI.md` |
| Wire board communication | `QUICK_REF.md` → `COMMUNICATION.md` |
| Add plugin integration | `QUICK_REF.md` → `PLUGINS_INTEGRATION.md` |
| Share service across modules | `QUICK_REF.md` → `CROSS_MODULE_DI.md` |
| Implement service layer | `QUICK_REF.md` → `SERVICE_LAYER.md` → `LAYERING.md` |
| Write tests | `QUICK_REF.md` → `TESTING.md` |
| Review code | `QUICK_REF.md` → `REVIEWER_CHECKLIST.md` |
| Find skeleton code | `QUICK_REF.md` → `EXAMPLES.md` → one matching `EXAMPLES_*.md` |

---

## Assumed Project Shape

The pack assumes an iOS project with:

- Module root such as `{ModuleRoot}/{ModuleName}/`.
- Interface target `{ModuleName}` containing `IO/**/*.swift`.
- Implementation target `{ModuleName}Plugins` containing `Sources/**/*.swift`.
- App-level dependency configuration such as `Podfile` or equivalent package wiring.
- Boardy `Motherboard`, `BoardProducer`, and `ServiceMap` usage.
- Plugin host that installs `LauncherPlugin`s before launch.
- Build/test commands documented outside generic specs, referenced via `{ProjectConfigPath}`.

If your project uses different folders or package tooling, update `{ProjectConfigPath}` and project `@CLAUDE.md`; do not hard-code those values into generic rules.

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

- Load `QUICK_REF.md` first.
- Keep Interface Modules public and Implementation Modules internal.
- Consumers import Interface Modules only, never Plugins.
- Board → Controller communication uses event buses, not stored/retrieved controller references.
- `watch(content:)` is lifecycle tracking only.
- Duplicate-activation guard only when a board is explicitly single-session.
- Presenter is the only Domain → ViewModel mapper.
- Domain stays pure: no UIKit, Boardy, networking SDKs, DTOs, or vendor types.
- Concrete Builder structs are composition roots; Board depends on `Buildable` protocol only.
- Project-specific values live in `{ProjectConfigPath}`.

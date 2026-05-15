<!-- Created by claude-opus-4-7 on 2026-05-09 -->

# ARCHITECTURE — Top-Level Overview

> **Purpose**: Single page that explains the architecture's pillars and how the per-spec rules in this folder fit together. Read this before any per-spec rule. Aligns with *Modern large-scale iOS app development* (PDF in this folder).

---

## 1. Five Pillars

| # | Pillar | Goal | Spec |
|---|--------|------|------|
| 1 | **SDK-first** | Prefer first-party platform frameworks; minimize third-party surface | `.claude/rules/SDK_FIRST.md` |
| 2 | **Modular + Interface Module** | Split each feature into a public **Interface Module** (`{Module}` / IO) and a private **Implementation Module** (`{Module}Plugins` / Sources). Other features depend only on the Interface Module. | `.claude/rules/MODULE_CREATION.md`, `.claude/rules/IO_INTERFACE.md` |
| 3 | **Plugins composition** | Apps assemble at runtime via `PluginLauncher` + `LauncherPlugin` + `ModulePlugin` + `URLOpenerPlugin`. The host is the app entry file declared by `.claude/rules/PROJECT_CONFIG.md`. | `.claude/rules/PLUGINS_INTEGRATION.md` |
| 4 | **Micro-services Composable (Boardy)** | Boards are independently activatable services. The Motherboard is the gateway; `BoardProducer` is the registry; `ActivatableBoard` / `InteractableBoard` are the contracts. | `.claude/rules/MICROBOARD_UI.md`, `.claude/rules/MICROBOARD_NONUI.md`, `.claude/rules/COMMUNICATION.md`, `.claude/rules/COMPOSABLE_BOARD.md` |
| 5 | **Domain-Driven Layering** | Pure domain core; Business Application (VIP) on top; Infrastructure & UI at the edges. Dependencies point inward. | `.claude/rules/LAYERING.md`, `.claude/rules/SERVICE_LAYER.md`, `.claude/rules/VIP_COMPONENTS.md` |

---

## 2. Terminology Map

The PDF and this codebase use overlapping vocabularies. Treat the left column as canonical; right column entries are aliases that appear in legacy code or specs.

| Canonical (PDF) | Codebase alias |
|-----------------|----------------|
| Interface Module | IO module / `{Module}` target |
| Implementation Module | Plugins module / `{Module}Plugins` target |
| Business Application Layer | VIP layer (Microboards) |
| Domain Layer | Services/Domain |
| Infrastructure Layer | Services/Infra |
| Plugin host | `PluginLauncher` |
| Service registry | `BoardProducer` |
| Service gateway | Motherboard |
| Service contract | `ActivatableBoard`, `InteractableBoard` |
| Service request | `BoardID` + `Input` |
| Service response | `Output` (flow) |
| Service command | `Command` (interaction) |

---

## 3. Module Anatomy (canonical)

```
{ModuleRoot}/{Module}/
├── {Module}.podspec               ← Interface Module (public)
├── {Module}Plugins.podspec        ← Implementation Module (internal)
├── IO/                            ← Interface: BoardID, InOut, ServiceMap
│   ├── {Module}ServiceMap.swift
│   └── {Board}/
│       ├── {Board}IOInterface.swift
│       ├── {Board}InOut.swift
│       └── ServiceMap+{Board}.swift
└── Sources/                       ← Implementation: hidden behind Interface
    ├── Plugins/                   ← ModulePlugin + LauncherPlugin
    ├── Microboards/{Board}/       ← Business Application (VIP) per board
    │   ├── {Board}Protocols.swift
    │   ├── {Board}Board.swift
    │   ├── {Board}Builder.swift
    │   ├── {Board}Interactor.swift
    │   ├── {Board}Presenter.swift
    │   ├── {Board}ViewController.swift
    │   └── ServiceMap+{Board}.swift
    └── Services/                  ← Domain + Application + Infra
        ├── Domain/{Models, Repositories, Services}
        ├── Application/{Action}UseCase.swift
        └── Infra/
```

A consumer module **must depend on `{Module}` only** — never on `{Module}Plugins`. The Implementation Module is the leaf; the Interface Module is the root of every cross-module reference.

---

## 4. Runtime Composition

```
                ┌────────── App entry file ───────────┐
                │ PluginLauncher                            │
                │   .install({Module}LauncherPlugin())  ×N  │
                │   .initialize()                           │
                │   .launch(in: window) { mainboard in ... }│
                └───────────────┬───────────────────────────┘
                                │
                       Mainboard (gateway)
                                │
            ┌───────────────────┼────────────────────┐
            ▼                   ▼                    ▼
     {ModuleA}                {ModuleB}            {ModuleC}
     ServiceMap                ServiceMap          ServiceMap
        │                         │                   │
   .ioBoardX     .ioBoardY (cross-module via IO only)  ...
```

Activation always traverses `motherboard.serviceMap.mod{Module}.io{Board}.activation.activate(with:)` — never a direct class reference. See `.claude/rules/COMMUNICATION.md` for the activation / flow / interaction triad.

---

## 5. Per-Board Architecture (VIP)

```
   ViewController ──interactor──► Interactor ──► UseCase ──► Repository
        ▲                            │
        │ Viewable (ViewModel)       │ Presentable (domain model)
        │                            ▼
   Presenter ◄─────────────────────  ┘
                  weak view

   ViewController ──actionDelegate──► Board ──► child board activations
        Interactor   ──delegate──────► Board (control delegate)
```

Strict invariants:
1. **View is Humble** — zero logic; renders ViewModels, forwards events.
2. **Presenter is the only ViewModel mapper** — Interactor passes domain models only.
3. **Interactor never references `ActionDelegate`** — pure UI navigation goes `View → ActionDelegate(Board)` directly.
4. **Board is stateless** — all per-session state lives in the Interactor (UI boards) or Controller (Viewless boards).
5. **Unidirectional flow** — events propagate `View → Interactor → UseCase → Presenter → View`.

Full rules in `.claude/rules/VIP_COMPONENTS.md`. See `.claude/rules/MICROBOARD_UI.md` for UI boards and `.claude/rules/MICROBOARD_NONUI.md` for the non-UI variants (Flow / BlockTask / Task / Result / Barrier / Viewless / Empty).

---

## 6. Cross-Module Service Sharing

When a service must be consumed by more than one module, follow `.claude/rules/CROSS_MODULE_DI.md`:

1. **Pattern A (preferred)** — wrap the service in a `BlockTaskBoard`, expose it through the owner's Interface Module. Consumers activate via `motherboard.serviceMap.mod{Owner}.io{Service}`.
2. **Pattern B (secondary)** — split the protocol into a third pod `{Module}Core`; resolve via `Resolver` (`@LazyInjected`) at activation time.

Never depend on `{Module}Plugins` from another module. Library/utility-only modules are exempt from cross-module rules.

---

## 7. Spec Routing

Use `.claude/rules/QUICK_REF.md` for the day-to-day routing table. This file is the high-level orientation; `.claude/rules/QUICK_REF.md` is the operational index.

| You are about to... | Read |
|---------------------|------|
| Scaffold a new module | `.claude/rules/MODULE_CREATION.md` |
| Define a public board's IO | `.claude/rules/IO_INTERFACE.md` |
| Build a UI board | `.claude/rules/MICROBOARD_UI.md` + `.claude/rules/VIP_COMPONENTS.md` |
| Build a non-UI board | `.claude/rules/MICROBOARD_NONUI.md` (Decision Tree first) |
| Wire a Plugin / Launcher | `.claude/rules/PLUGINS_INTEGRATION.md` |
| Compose tabs / sections | `.claude/rules/COMPOSABLE_BOARD.md` |
| Author UseCases / repositories / domain models | `.claude/rules/SERVICE_LAYER.md` + `.claude/rules/LAYERING.md` |
| Connect boards (activation / flow / bus) | `.claude/rules/COMMUNICATION.md` |
| Share a service across modules | `.claude/rules/CROSS_MODULE_DI.md` |
| Write tests | `.claude/rules/TESTING.md` |
| Review code | `.claude/rules/REVIEWER_CHECKLIST.md` |
| Look up a code skeleton | `.claude/rules/EXAMPLES.md` (index) |

---

## 8. Project Binding

This document is generic. Project-specific names, schemes, simulators, and remote URLs live in `.claude/rules/PROJECT_CONFIG.md`. When a spec references `{Workspace}`, `{MainScheme}`, `{Simulator}`, `{BaseBranch}`, etc., resolve them through `.claude/rules/PROJECT_CONFIG.md`.

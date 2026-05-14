---
name: boardy-vip-review
description: Use when reviewing a pull request or verifying implementation on a Boardy+VIP project — provides the complete architecture compliance checklist covering VIP components, board lifecycle, IO/Sources access, communication patterns, and extensible provider rules
---

# Boardy+VIP Code Review Checklist

## Architecture (every PR)

- [ ] View has ZERO logic — no conditionals, no business decisions
- [ ] Unidirectional flow: ViewController → Interactor → UseCase → Presenter → ViewController
- [ ] All IO types are `public`; all Sources types are `internal`
- [ ] No module imports `{ModuleNamePlugins}` — only IO modules imported cross-module
- [ ] Async UI updates in `await MainActor.run { [weak self] in ... }`
- [ ] `weak var view` in every Presenter; `weak var delegate` in every Interactor
- [ ] `registerFlows()` called in `init`, never in `activate()`
- [ ] Domain layer: no UIKit, no Boardy, no network frameworks
- [ ] `sharedRepository` / `sharedTracker` stored properties on ModulePlugin, not locals
- [ ] **Board is STATELESS** — no stored state on Board; all state in Controller
- [ ] **Board→Controller via event buses** — never stored/retrieved controller references
- [ ] **Correct communication mechanism** — `sendOutput()` direct parent; `broadcastAction()` upstream ancestors; Command Motherboard→active child or sibling

## Per-Activation Resources

- [ ] No per-activation service stored as Board property
- [ ] `attachObject(service)` immediately after service creation in `activate()`
- [ ] `complete()` called after `sendOutput()` to release attached object
- [ ] Concurrency guard is dedicated class, not a flag on Board/Controller
- [ ] Routing/provider config injected into Controller via Builder, not stored on Board

## Extensible Provider Architecture

- [ ] `public enum {Feature}ProviderConfiguration` does NOT exist — enum form forbidden
- [ ] `public protocol {Feature}ProviderConfiguration {}` — marker only, no methods
- [ ] `protocol Internal{Feature}ProviderConfiguration` — `internal`, has factory methods
- [ ] Concrete configs are `public struct` conforming to internal factory protocol
- [ ] `{Type}ProviderInOut.swift` defines `typealias {Type}ProviderInput = Void`
- [ ] Provider boards use `typealias InputType = {Type}ProviderInput` (named alias, never `Void` directly)
- [ ] Unified `BoardID` per service type (not per provider × type combination)
- [ ] `ModulePlugin.internalContinuousRegistrations` uses `as!` cast + factory dispatch — no `switch` on provider

## Module Structure

- [ ] Module lives directly under `{ModuleRoot}/{ModuleName}/` (not nested)
- [ ] Two podspecs: IO + Plugins
- [ ] IO: `source_files = 'IO/**/*.swift'`; Plugins: `source_files = 'Sources/**/*.swift'`
- [ ] `s.dependency` name only, no `:path =>`
- [ ] Podfile uses `:path =>` (hash-rocket)
- [ ] `pod install` run after structural changes
- [ ] LauncherPlugin wired in app entry file via `.install(launcherPlugin:)`
- [ ] App entry imports `{ModuleNamePlugins}`, not `{ModuleName}`

## IO Layer

- [ ] `{ModuleName}ServiceMap` is `public final class`
- [ ] Public BoardID: `"pub.mod.{ModuleName}IO.{BoardName}"`
- [ ] Internal BoardID: `"mod.{ModuleName}.{BoardName}"`
- [ ] All Input/Output/Command/Action types are `public`
- [ ] `context: UIViewController?` in Input is `weak var`
- [ ] `BlockTaskParameter<Input, Output>` typealias present
- [ ] ServiceMap extension on `{ModuleName}ServiceMap`, not global `ServiceMap`

## UI Board (Full VIP)

- [ ] Extends `ModernContinuableBoard`
- [ ] All 4 `Guaranteed*` conformances + typealiases
- [ ] `private let builder: {Name}Buildable`
- [ ] `watch(content: component.controller)` for lifecycle only (not communication)
- [ ] `motherboard.putIntoContext(vc)` BEFORE `show()`
- [ ] `rootViewController.show(vc)` — no nav wrapping
- [ ] `completeBus` connected in `activate()` AFTER `show()`
- [ ] Board conforms to `{Name}Delegate`

## Non-UI Board — Viewless

- [ ] Controller is `NSObject` subclass
- [ ] Controller attached to appropriate context
- [ ] NO double-activation guard
- [ ] ALL state in Controller, not Board
- [ ] Controller's `delegate` is `weak var`
- [ ] Protocols: Controllable, ControlDelegate, Delegate, Interface, Buildable
- [ ] Event buses for Board→Controller communication
- [ ] Buses connected in `activate()`, transported in `registerFlows()`

## VIP Components

### Protocols.swift
- [ ] ALL protocols for one board in ONE file
- [ ] `{Name}Interactable` NOT in Protocols.swift (lives in ViewController)
- [ ] `{Name}Presentable` NOT in Protocols.swift (lives in Interactor)
- [ ] `{Name}Viewable` NOT in Protocols.swift (lives in Presenter)

### Interactor
- [ ] `{Name}Presentable` defined at top of Interactor file
- [ ] `{Name}Presentable` methods accept domain model types only — never ViewModels
- [ ] `weak var delegate: {Name}ControlDelegate!`
- [ ] Conforms to `{Name}Controllable`
- [ ] **NO ViewModel construction**
- [ ] Interactor does NOT declare/reference `ActionDelegate`

### Presenter
- [ ] `{Name}Viewable` defined at top of Presenter file
- [ ] ViewModels defined in Presenter file
- [ ] `weak var view: {Name}Viewable!`
- [ ] All formatting/display logic here, NONE in ViewController

### ViewController
- [ ] `{Name}Interactable` defined at top of ViewController file
- [ ] `weak var actionDelegate: {Name}ActionDelegate!`
- [ ] `viewDidLoad` calls `interactor.didBecomeActive()`
- [ ] Only renders and forwards — no conditionals or business logic

### Builder
- [ ] Wires Presenter.view = viewController
- [ ] Wires interactor.delegate = delegate (Board)
- [ ] Wires viewController.interactor = interactor
- [ ] Wires viewController.actionDelegate = delegate (Board)
- [ ] Returns `{Name}Interface(userInterface: vc, controller: interactor)`

## Service Layer

- [ ] Domain models: pure Swift structs/enums, no UIKit, no Boardy
- [ ] Repository protocols in Domain/Repositories
- [ ] UseCase naming: protocol = `{Action}UseCase`, impl = `{Action}UseCaseInteractor`
- [ ] Infrastructure DTOs: Codable in Infra, not Domain
- [ ] `.toDomain()` mapping in Infra layer

## Context Navigation

- [ ] `backToPrevious()` on current ViewController via bus (not rootViewController)
- [ ] `returnHere()` on destination ViewController via bus (not rootViewController)
- [ ] Return bus connected at destination Board, transported from `registerFlows()`
- [ ] Alerts/modals on `rootViewController.topPresentedViewController`
- [ ] No direct navigation method calls without bus

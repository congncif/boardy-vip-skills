<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Microboard with UI (Full VIP Board)

> **Load this spec** when creating a Microboard that has a UIViewController.
> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Template: `@.claude/rules/templates/module-template/Templates/Full UI Board.xctemplate/VIP`
> Companion specs: `@.claude/rules/VIP_COMPONENTS.md` (per-component rules), `@.claude/rules/EXAMPLES_VIP_BOARD.md` (full skeleton).

---

## Board Class Pattern

```swift
// Sources/Microboards/{FeatureName}/{FeatureName}Board.swift
import Boardy
import Foundation
import SiFUtilities
import UIKit

final class {FeatureName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    // MARK: - Type declarations
    typealias InputType = {FeatureName}Input
    typealias OutputType = {FeatureName}Output
    typealias FlowActionType = {FeatureName}Action
    typealias CommandType = {FeatureName}Command

    // MARK: - Dependencies
    private let builder: {FeatureName}Buildable

    // MARK: - Event Buses
    private let completeBus = Bus<Bool>()

    // MARK: - Init
    init(identifier: BoardID, builder: {FeatureName}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    // MARK: - GuaranteedBoard
    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        let viewController = component.userInterface

        watch(content: component.controller)
        motherboard.putIntoContext(viewController)
        rootViewController.show(viewController)

        completeBus.connect(target: self) { target, isDone in
            target.rootViewController.returnHere { [weak target] in
                target?.complete(isDone)
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }

    func interact(guaranteedCommand: CommandType) {}
}

// MARK: - {FeatureName}Delegate
extension {FeatureName}Board: {FeatureName}Delegate {
    func loadData() {}

    func close(_ isDone: Bool) {
        completeBus.transport(input: isDone)
    }

    func performCompletion(_ isDone: Bool) {
        completeBus.transport(input: isDone)
    }

    func presentChildBoard(with data: SomeData) {
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoard.activation.activate(with: data)
    }
}

// MARK: - Flow registrations (child board coordination)
private extension {FeatureName}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoardA.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{ModuleName}Plugins
                        .ioChildBoardB.activation.activate()
                case .done:
                    target.completeBus.transport(input: true)
                }
            }
    }

    func complete(_ isDone: Bool) {
        sendOutput(/* appropriate output value */)
    }
}
```

---

## Key Board Patterns

### `ModernContinuableBoard` (base class)
All UI boards extend `ModernContinuableBoard` (not plain `Board`).

### Protocol conformances
```swift
// Always all four:
GuaranteedBoard                 // activate(withGuaranteedInput:)
GuaranteedOutputSendingBoard    // sendOutput(_:)
GuaranteedActionSendingBoard    // sendAction(_:)
GuaranteedCommandBoard          // interact(guaranteedCommand:)
```

### `watch(content:)`
```swift
watch(content: component.controller)  // in activate()
```
This attaches the controller to Boardy lifecycle tracking. Do not use watched content as a communication channel. Board → Controller communication must go through event buses; View/Interactor → Board communication goes through delegates.

### `motherboard.putIntoContext(_:)`
```swift
motherboard.putIntoContext(viewController)
```
Must be called before presenting the ViewController. Registers it with the motherboard's navigation context.

### Double-activation guard
Use a duplicate-activation guard only when this UI board is explicitly designed as a single-session board. The guard is not part of Board→Controller communication.
```swift
func activate(withGuaranteedInput input: InputType) {
    // Optional: return early here only for single-session UI boards.
    // ...
}
```

### Presentation — always use `rootViewController.show(_:)` (SiFUtilities)

```swift
// ✅ Standard — push/show via SiFUtilities
rootViewController.show(viewController)

// ✅ Return to this screen and then execute callback
rootViewController.returnHere { [weak self] in
    self?.complete(isDone)
}

// ❌ Do NOT use nav wrapping or custom context — unnecessary complexity
// let nav = UINavigationController(rootViewController: viewController)
// context.presentViewController(nav) / rootViewController.topPresentViewController(nav)
```

### Bus usage
```swift
// Standard: only completeBus needed
private let completeBus = Bus<Bool>()

// completeBus wired in activate() after show()
completeBus.connect(target: self) { target, isDone in
    target.rootViewController.returnHere { [weak target] in
        target?.complete(isDone)
    }
}
```

### `registerFlows()` in init
Child board flow registrations go in a private `registerFlows()` called from `init`, NOT in `activate()`.

---

## ServiceMap Extension

**File:** `Sources/Microboards/{FeatureName}/ServiceMap+{FeatureName}.swift`

```swift
import Boardy
import Foundation

extension {ModuleName}PluginsServiceMap {
    var io{FeatureName}: {FeatureName}MainDestination {
        mainboard.io{FeatureName}()
    }
}
```

---

## complete(_:) vs sendOutput(_:)

```swift
// complete(isDone: Bool) — Board's internal helper
// Calls sendOutput with the right output value
private func complete(_ isDone: Bool) {
    if isDone {
        sendOutput(.done)
    } else {
        sendOutput(.cancelled)  // or appropriate case
    }
}
```

The `complete()` method is a private convenience that maps the `Bool` signal to typed output.

---

## Checklist for UI Board
- [ ] Extends `ModernContinuableBoard`
- [ ] All 4 `Guaranteed*` protocol conformances declared
- [ ] `typealias` for all 4 type parameters (InputType, OutputType, FlowActionType, CommandType)
- [ ] Duplicate-activation guard omitted unless this UI board is explicitly single-session
- [ ] `watch(content: component.controller)` called in `activate()`
- [ ] `motherboard.putIntoContext(viewController)` called before `show()`
- [ ] `rootViewController.show(viewController)` used — **no nav wrapping, no context**
- [ ] `completeBus` connected in `activate()` after `show()`
- [ ] `registerFlows()` called in `init`, not `activate()`
- [ ] Board conforms to `{FeatureName}Delegate`
- [ ] Registered in `ModulePlugin`'s `internalContinuousRegistrations`

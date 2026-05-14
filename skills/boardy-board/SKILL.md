---
name: boardy-board
description: Use when implementing a Boardy microboard — decides board type (UI VIP, Flow, BlockTask, Viewless), provides key patterns for Board shell, Builder, event buses, and complete()/sendOutput() semantics
version: 1.1.1
---

# Boardy+VIP Board Implementation

## Board Type Decision

```
Has UIViewController?
  YES → UI VIP Board (see UI Board section)
  NO  → Continue ↓

Does an existing VIP board already own this flow?
  YES → Add registerFlows() to that board. No new non-UI board needed.
  NO  → Continue ↓

Single async task, per-activation result routing?
  YES → BlockTask Board

Coordinator that stores child output between steps?
  YES → Viewless Board

Pure routing, no state?
  YES → Flow Board (finishBus only)
```

---

## UI VIP Board

### Board Shell (6 required conformances)

```swift
final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let builder: {Name}Buildable
    private let completeBus = Bus<Bool>()

    init(identifier: BoardID, builder: {Name}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows() // ALWAYS last in init
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        watch(content: component.controller)           // lifecycle tracking only
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
        completeBus.connect(target: self) { target, isDone in
            target.rootViewController.returnHere { [weak target] in
                target?.complete(isDone)
            }
        }
    }

    // Override to gate activation behind a barrier board (see Activation Barrier section)
    func activationBarrier(withGuaranteedInput _: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: CommandType) {}
}

extension {Name}Board: {Name}Delegate {
    func close(_ isDone: Bool) { completeBus.transport(input: isDone) }
    func performCompletion(_ isDone: Bool) { completeBus.transport(input: isDone) }
    func presentChild(with data: SomeData) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChild.activation.activate(with: data)
    }
}

private extension {Name}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChild.flow.addTarget(self) { target, output in
                switch output {
                case .done: target.completeBus.transport(input: true)
                }
            }
    }
    func complete(_ isDone: Bool) {
        sendOutput(isDone ? .completed : .cancelled)
    }
}
```

### Presentation Rules
- `watch(content:)` = lifecycle tracking only, NOT communication
- `motherboard.putIntoContext(vc)` BEFORE `show()`
- `rootViewController.show(vc)` — no nav wrapping
- No double-activation guard unless explicitly single-session
- `completeBus` connected AFTER `show()`

---

## Flow Board (stateless coordinator)

```swift
final class {Name}Board: ModernContinuableBoard, ... {
    private let finishBus = Bus<Void>() // ONLY stored property allowed

    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChild.activation.activate(with: ChildInput(context: input.context))
        finishBus.deliver { input.completion?() }
    }

    func activationBarrier(withGuaranteedInput _: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: CommandType) {}
}

private extension {Name}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChild.flow.addTarget(self) { target, output in
                switch output {
                case .done:
                    target.finishBus.transport()
                    target.sendOutput(.completed)
                    target.complete()
                }
            }
    }
}
```

---

## Viewless Board (stateful coordinator with Controller)

### Board Shell

```swift
final class {Name}Board: ModernContinuableBoard, ... {
    private let builder: {Name}Buildable

    // One bus per Board→Controller action
    private let childOutputBus = Bus<ChildOutputType>()

    init(identifier: BoardID, builder: {Name}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        // Connect buses BEFORE start()
        childOutputBus.connect(target: component.controller) { c, out in
            c.didReceiveChildOutput(out)
        }
        attachObject(component.controller) // lifecycle tied to Board
        component.controller.start()
    }
}

extension {Name}Board: {Name}Delegate {
    func activateChild(context: UIViewController?) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChild.activation.activate(with: ChildInput(context: context))
    }
    func finishFlow(output: OutputType) {
        sendOutput(output)
        complete()
    }
}

private extension {Name}Board {
    func registerFlows() {
        // Transport via bus — NEVER call controller directly
        motherboard.serviceMap.mod{Module}Plugins
            .ioChild.flow.addTarget(self) { target, output in
                target.childOutputBus.transport(input: output)
            }
    }
}
```

### Controller

```swift
final class {Name}Controller: NSObject { // NSObject required for Attachable
    weak var delegate: {Name}ControlDelegate?
    private let input: {Name}Input
    private let useCase: SomeUseCase
    private var state: Bool = false // ALL mutable state here, not on Board

    init(input: {Name}Input, useCase: SomeUseCase) {
        self.input = input
        self.useCase = useCase
    }
}

extension {Name}Controller: {Name}Controllable {
    func start() { delegate?.activateChild(context: input.context) }
    func didReceiveChildOutput(_ output: ChildOutputType) {
        Task { [weak self] in
            guard let self else { return }
            let result = await useCase.execute()
            await MainActor.run { [weak self] in
                self?.state = true
                self?.delegate?.finishFlow(output: .completed(result))
            }
        }
    }
}
```

---

## complete() Semantics

| Board type | Call complete()? |
|------------|-----------------|
| Stateless VIP / Flow board | Usually NOT needed |
| Flow board as root coordinator | YES — after sendOutput() |
| Viewless board (Controller attached) | YES — after sendOutput() |
| BlockTaskBoard | NO — framework auto-completes |

**Rules:**
- `sendOutput()` BEFORE `complete()`
- `complete()` at most once — second call raises assertion
- Confirm all streams/observers terminated before calling
- A barrier board calls `complete()` in every exit path — this is the signal that lets the gated board activate

---

## Activation Barrier

Gate Board B's activation behind Board A completing first.

### Qualifying Board A as a Barrier

Any board that calls `complete()` at the end of its work qualifies — no structural changes needed.

```swift
// Board A (barrier board) — all exit paths must call complete()
func finish(_ result: {BarrierName}Result) {
    sendOutput(result)   // typed result, not Void
    complete()           // ← releases the gate; always passes through
}
```

### Declaring the Barrier on Board B (Gated Board)

```swift
// {GatedName}Board.swift
func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? {
    motherboard.serviceMap.mod{BarrierModule}
        .io{BarrierName}
        .activation
        .barrier(scope: .mainboard, with: {BarrierName}Input())
}
```

**Scope:** `.mainboard` = new instance per activation (default). `.application` = shared app-wide singleton.

**Critical:** use `.barrier(with: {BarrierName}Input(...))` — not `.barrier()` — when barrier board InputType ≠ Void. `.barrier()` passes `()` which fails the type cast silently.

---

## Navigation Patterns

```swift
// Simple back (current screen)
cancelBus.connect(target: component.userInterface) { vc in
    vc.backToPrevious()
}

// Return to THIS coordinator's screen
returnBus.connect(target: component.userInterface) { vc in
    vc.returnHere()
}
// Transport returnBus from registerFlows() on child completion

// Alerts always on topmost VC
rootViewController.topPresentedViewController.present(alert, animated: true)
```

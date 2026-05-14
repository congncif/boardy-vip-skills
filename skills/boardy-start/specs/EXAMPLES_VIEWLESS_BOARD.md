<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: Viewless Board

All 4 files for a non-UI board that has stateful business logic (UseCase calls).
Pattern: like Full VIP Board but without Presenter and ViewController.
Placeholders: `{Name}` = board name, `{Module}` = module name, `{PubName}` = public board name in IO.
Files live in `Sources/Microboards/{Name}/`.

---

```swift
// {Name}Protocols.swift
import UIKit

// Inward: Board pushes lifecycle events into Controller
protocol {Name}Controllable: AnyObject {
    func start()
    func didReceiveChildOutput()   // called by Board from registerFlows
}

// Outward: Controller requests Board actions
protocol {Name}ControlDelegate: AnyObject {
    func activateChild(context: UIViewController?)
    func finishFlow(output: {PubName}Output)
}

// Board conforms to this
protocol {Name}Delegate: {Name}ControlDelegate {}

struct {Name}Interface {
    let controller: {Name}Controllable
}

protocol {Name}Buildable {
    func build(withDelegate delegate: {Name}Delegate?,
               input: {Name}Input) -> {Name}Interface
}
```

```swift
// {Name}Controller.swift
import Foundation

// NSObject required for Boardy Attachable conformance
final class {Name}Controller: NSObject {
    weak var delegate: {Name}ControlDelegate?

    private let input: {Name}Input
    private let useCase: {Action}UseCase
    private var hasCompleted = false   // state lives here, NOT in Board

    init(input: {Name}Input, useCase: {Action}UseCase) {
        self.input = input
        self.useCase = useCase
    }
}

extension {Name}Controller: {Name}Controllable {
    func start() {
        delegate?.activateChild(context: input.context)
    }

    func didReceiveChildOutput() {
        Task { [weak self] in
            guard let self else { return }
            let result = await useCase.execute()
            await MainActor.run { [weak self] in
                guard let self else { return }
                hasCompleted = true
                delegate?.finishFlow(output: .completed(result))
            }
        }
    }
}
```

```swift
// {Name}Builder.swift
import Foundation

struct {Name}Builder: {Name}Buildable {
    let useCase: {Action}UseCase

    func build(withDelegate delegate: {Name}Delegate?,
               input: {Name}Input) -> {Name}Interface {
        let controller = {Name}Controller(input: input, useCase: useCase)
        controller.delegate = delegate
        return {Name}Interface(controller: controller)
    }
}
```

```swift
// {Name}Board.swift
import Boardy
import Foundation
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let builder: {Name}Buildable

    // Event buses for Board→Controller communication (one bus per action)
    private let childOutputBus = Bus<Void>()

    init(identifier: BoardID, builder: {Name}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()   // always in init
    }

    func activate(withGuaranteedInput input: {Name}Input) {
        let component = builder.build(withDelegate: self, input: input)

        // Connect event buses to controller
        childOutputBus.connect(target: component.controller) { controller, _ in
            controller.didReceiveChildOutput()
        }

        // Attach controller to appropriate context (Board context preferred)
        attachObject(component.controller)
        component.controller.start()
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

extension {Name}Board: {Name}Delegate {
    func activateChild(context: UIViewController?) {
        motherboard.serviceMap.mod{Module}Plugins
            .io{Child}.activation.activate(with: ChildInput(context: context))
    }
    func finishFlow(output: {PubName}Output) {
        sendOutput(output)
        complete()
    }
}

private extension {Name}Board {
    func registerFlows() {
        // Transport events via bus instead of calling controller directly
        motherboard.serviceMap.mod{Module}Plugins
            .io{Child}.flow.addTarget(self) { target, _ in
                target.childOutputBus.transport(input: ())
            }
    }
}
```

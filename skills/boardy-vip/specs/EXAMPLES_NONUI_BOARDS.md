<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: Non-UI Boards (Flow + BlockTask)

Two patterns for boards with no ViewController.
Placeholders: `{Name}` = board name, `{Module}` = module name.

---

## Flow Board

Use when: orchestrating child boards in sequence/parallel with NO business logic.
No Builder. No UseCase calls. Pure routing.

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let finishBus = Bus<Void>()

    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        motherboard.serviceMap.mod{Module}
            .io{ChildA}.activation.activate(with: ChildAInput(context: input.context))
        finishBus.deliver { input.completion?() }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

private extension {Name}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}
            .io{ChildA}.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{Module}
                        .io{ChildB}.activation.activate()
                case .done:
                    target.finishBus.transport()
                    target.sendOutput(.completed)
                    target.complete()
                }
            }

        motherboard.serviceMap.mod{Module}
            .io{ChildB}.flow.addTarget(self) { target, _ in
                target.finishBus.transport()
                target.sendOutput(.completed)
                target.complete()
            }
    }
}
```

---

## BlockTask Board

Use when: one discrete async operation, then done. No UI, no child boards.

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let useCase: {Action}UseCase

    init(identifier: BoardID, useCase: {Action}UseCase, producer: ActivatableBoardProducer) {
        self.useCase = useCase
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await useCase.execute(input)
                await MainActor.run { [weak self] in
                    self?.sendOutput(.completed(result))
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.sendOutput(.failed(error))
                }
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Composable Board

> **Load this spec** when building a screen that hosts multiple boards simultaneously and long-lived — TabBar navigation, section-based lists, or any container where N boards are activated concurrently and each manages its own UI region.
> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `.claude/rules/MICROBOARD_UI.md` (single VIP board), `.claude/rules/COMMUNICATION.md` (flow patterns).

---

## What is a Composable Board?

A **Composable Board** is a two-level architecture where:

| Role | Responsibility |
|------|---------------|
| **Parent Board** | Owns the container ViewController (`UITabBarController` or custom), creates a `FlowComposableMotherboard`, activates all child boards simultaneously |
| **Child Board** | Standard VIP board that, instead of presenting itself, registers its ViewController as a `UIElement` into the composable container via `putToComposer()` |

The `FlowComposableMotherboard` acts as an internal mini-motherboard that:
- Holds all child boards and their lifecycles
- Forwards `UIElementAction` from child boards to the container ViewController
- Forwards activation/action flows back to the parent board's motherboard

**Contrast with normal boards:**
- Normal board: activated one at a time, shows and dismisses independently
- Composable child board: activated simultaneously with siblings, long-lived, no independent dismiss

---

## Dependencies

Add `UIComposable` to the Plugins podspec:
```ruby
s.dependency 'UIComposable'
```

Import in Board files:
```swift
import UIComposable   # child boards and parent board
```

---

## Part 1 — Parent Board

The parent board orchestrates the container.

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation
import SiFUtilities
import UIComposable
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let builder: {Name}Buildable

    init(identifier: BoardID, builder: {Name}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        // 1. Build the container ViewController (must be AttachableObject & ComposableInterface)
        let component = builder.build(withDelegate: self)
        let viewController = component.userInterface
        motherboard.putIntoContext(viewController)

        // 2. Create ComposableMotherboard and attach it to the container
        //    The ViewController must conform to AttachableObject & ComposableInterface
        let composableBoard = attachComposableMotherboard(to: viewController)

        // 3. Register flows on composable child boards (optional)
        composableBoard.serviceMap.mod{ModuleName}
            .ioChildBoardA.flow.addTarget(self) { target, output in
                // handle output from child boards
            }

        // 4. Activate all child boards simultaneously
        composableBoard.serviceMap.mod{ModuleName}.ioChildBoardA.activation.activate()
        composableBoard.serviceMap.mod{ModuleName}.ioChildBoardB.activation.activate()
        composableBoard.serviceMap.mod{ModuleName}.ioChildBoardC.activation.activate()

        // 5. Present the container
        switch input.presentation {
        case .rootContext:
            window.setRootViewController(viewController)
        case .present:
            rootViewController.show(viewController)
        }
    }

    func activationBarrier(withGuaranteedInput _: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: CommandType) {}
}

extension {Name}Board: {Name}Delegate {
    func loadData() {}
}

private extension {Name}Board {
    func registerFlows() {}
}
```

### Parent Board — Key rules
- **No double-activation guard** — composable parent boards are usually permanent entry points
- **`attachComposableMotherboard(to: viewController)`** — the ViewController must conform to both `AttachableObject` and `ComposableInterface`
- Activate child boards via `composableBoard.serviceMap`, NOT `motherboard.serviceMap`
- Child boards are activated synchronously right after attachment — no async needed

---

## Part 2 — Child Board

Each child board registers itself as a `UIElement` into the composable container.

```swift
// Sources/Microboards/{ChildName}/{ChildName}Board.swift
import Boardy
import Foundation
import SiFUtilities
import UIComposable
import UIKit

final class {ChildName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {ChildName}Input
    typealias OutputType = {ChildName}Output
    typealias FlowActionType = {ChildName}Action
    typealias CommandType = {ChildName}Command

    private let builder: {ChildName}Buildable

    init(identifier: BoardID, builder: {ChildName}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput _: InputType) {
        let component = builder.build(withDelegate: self)
        let viewController = component.userInterface
        motherboard.putIntoContext(viewController)

        // Wrap in NavigationController for TabBar items
        let nav = UINavigationController(rootViewController: viewController)
        nav.tabBarItem.title = "{Tab Title}"
        nav.tabBarItem.image = UIImage(named: "{tab-icon}")

        // Register as UIElement in the composable container
        let element = UIElement(identifier: identifier, contentViewController: nav)
        putToComposer(elementAction: .update(element: element))

        // Buses for receiving commands from parent
        returnBus.connect(target: viewController) { controller in
            controller.returnHere()
        }
    }

    func activationBarrier(withGuaranteedInput _: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: CommandType) {}

    private let returnBus = Bus<Void>()
}

extension {ChildName}Board: {ChildName}Delegate {
    func loadData() {}
}

private extension {ChildName}Board {
    func registerFlows() {}
}
```

### Child Board — Key rules
- **No `show(viewController)`** — child registers via `putToComposer()` instead
- **Wrap in `UINavigationController`** for tab-based UI; set `tabBarItem.title` and `tabBarItem.image`
- **`UIElement(identifier: identifier, contentViewController: nav)`** — `identifier` is the board's own BoardID
- Use `putToComposer(elementAction: .update(element:))` — `.update` adds or refreshes the element
- For section-based lists (no nav wrap needed): pass the `viewController` directly as `contentViewController`

---

## Part 3 — Container ViewController

The container ViewController must conform to `ComposableInterface` (and optionally `AttachableObject`).

### TabBar container
```swift
// Standard UITabBarController automatically becomes composable
// when registered with SiFUtilities UIComposable extension
// Implement ComposableInterface in your UITabBarController subclass:

final class {Name}ViewController: UITabBarController, {Name}UserInterface {
    weak var actionDelegate: {Name}ActionDelegate?

    // ComposableInterface conformance
    var composedElements: [UIElement] = []
    var elementSortRule: ((UIElement, UIElement) -> Bool)? = nil

    func composeInterface(elements: [UIElement]) {
        composedElements = elements
        viewControllers = elements.compactMap { $0.contentViewController }
    }
}
```

### Section-based list container
Use the built-in `ComposableListViewController` from UIComposable:
```swift
// Builder wires it directly — no subclass needed
let viewController = ComposableListViewController()
```

---

## Part 4 — Protocols.swift for Composable Parent

```swift
// {Name}Protocols.swift
import UIComposable
import UIKit

protocol {Name}Controllable: AnyObject {}

protocol {Name}ActionDelegate: AnyObject {}
protocol {Name}ControlDelegate: AnyObject {
    func loadData()
}
protocol {Name}Delegate: {Name}ActionDelegate, {Name}ControlDelegate {}

// UserInterface must be BOTH UIViewController and ComposableInterface
protocol {Name}UserInterface: UIViewController, ComposableInterface {}

struct {Name}Interface {
    let userInterface: {Name}UserInterface
    let controller: {Name}Controllable
}

protocol {Name}Buildable {
    func build(withDelegate delegate: {Name}Delegate?) -> {Name}Interface
}
```

> **Critical:** `{Name}UserInterface` extends both `UIViewController` **and** `ComposableInterface`. Without `ComposableInterface`, `attachComposableMotherboard(to:)` won't compile.

---

## Part 5 — Builder

```swift
struct {Name}Builder: {Name}Buildable {
    func build(withDelegate delegate: {Name}Delegate?) -> {Name}Interface {
        // For TabBar: use UITabBarController subclass
        let viewController = {Name}ViewController()
        viewController.actionDelegate = delegate

        // For section list: use ComposableListViewController
        // let viewController = {Name}ViewController() // which wraps ComposableListViewController

        let presenter = {Name}Presenter()
        presenter.view = viewController

        let interactor = {Name}Interactor(presenter: presenter)
        interactor.delegate = delegate

        viewController.interactor = interactor

        return {Name}Interface(userInterface: viewController, controller: interactor)
    }
}
```

---

## Part 6 — ModulePlugin Registration

Child boards and parent board are registered normally in `internalContinuousRegistrations`:

```swift
func internalContinuousRegistrations(
    sharedComponent: any SharedValueComponent,
    producer: any ActivatableBoardProducer
) -> [BoardRegistration] {
    // Parent (composable host)
    BoardRegistration(.mod{Name}) { identifier in
        {Name}Board(
            identifier: identifier,
            builder: {Name}Builder(),
            producer: producer
        )
    }

    // Child boards
    BoardRegistration(.mod{ChildA}) { identifier in
        {ChildA}Board(
            identifier: identifier,
            builder: {ChildA}Builder(),
            producer: producer
        )
    }

    BoardRegistration(.mod{ChildB}) { identifier in
        {ChildB}Board(
            identifier: identifier,
            builder: {ChildB}Builder(),
            producer: producer
        )
    }
}
```

---

## UIElement Actions Reference

```swift
// Add or update an element in the container
putToComposer(elementAction: .update(element: UIElement(identifier: identifier, contentViewController: vc)))

// Reload the element (triggers composeInterface again)
putToComposer(elementAction: .reload(identifier: identifier.rawValue))

// Remove the element's content (keeps placeholder)
putToComposer(elementAction: .removeContent(identifier: identifier.rawValue))

// Update configuration (custom data, e.g. badge count)
putToComposer(elementAction: .updateConfiguration(identifier: identifier.rawValue, configuration: badgeCount))
```

---

## When to Use Composable vs Normal Board

| Scenario | Use |
|----------|-----|
| Tab-based main navigation (all tabs alive simultaneously) | Composable Board |
| Section-based feed (each section = independent board) | Composable Board |
| Regular screen pushed/presented, one at a time | Normal Board with `show()` |
| Modal overlay | Normal Board with `show()` |
| Wizard/flow with steps | Non-UI flow boards |

---

## Checklist for Composable Board

### Parent Board
- [ ] `{Name}UserInterface` extends `UIViewController` **and** `ComposableInterface`
- [ ] `attachComposableMotherboard(to: viewController)` called in `activate()`
- [ ] Child boards activated via `composableBoard.serviceMap`, not `motherboard.serviceMap`
- [ ] No `show(viewController)` — parent presents container differently (setRoot or show)
- [ ] `import UIComposable` present

### Child Board
- [ ] `putToComposer(elementAction: .update(element:))` called in `activate()`
- [ ] No `show(viewController)` — child registers into composer
- [ ] `UINavigationController` wrapping for tab items (tabBarItem configured)
- [ ] `UIElement` uses board's own `identifier`
- [ ] `import UIComposable` present

### Container ViewController
- [ ] Conforms to `ComposableInterface` (`composedElements`, `composeInterface(elements:)`)
- [ ] For TabBar: sets `viewControllers` in `composeInterface`
- [ ] For list: uses `ComposableListViewController` (built-in)

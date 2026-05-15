# SPEC: VIP Components

> **Load this spec** when implementing Protocols, Interactor, Presenter, ViewController, or Builder for a Microboard.
> Reference: *Modern large-scale iOS app development* — Business Application layer inside Domain-driven Layered pillar.
> Companion specs: `.claude/rules/ARCHITECTURE.md` (overall picture), `.claude/rules/MICROBOARD_UI.md` (Board shell), `.claude/rules/EXAMPLES_VIP_BOARD.md` (concrete skeleton).

## VIP Architecture Overview

```
User Action (ViewController)
    │ actionDelegate / interactor
    ▼
Interactor ──────► UseCase(s)
    │                   │
    │ controlDelegate    │ domain model
    ▼                   ▼
Board ◄──────── Presenter ──► View (ViewController)
(delegate)              ViewModel
```

**Key difference from generic VIP:** The Board acts as the **delegate** (both ActionDelegate and ControlDelegate), not a separate router. The Interactor communicates outward via `delegate`, not directly to the Board.

---

## File Structure for One Microboard

```
Sources/Microboards/{FeatureName}/
├── {FeatureName}IOInterface.swift    ← BoardID, MainDestination typealias
├── {FeatureName}InOut.swift          ← Input, Output, Command, Action
├── {FeatureName}Protocols.swift      ← ALL protocols in one file
├── {FeatureName}Board.swift          ← Board: lifecycle + delegate impl
├── {FeatureName}Builder.swift        ← DI wiring, returns Interface struct
├── {FeatureName}Interactor.swift     ← Business logic + PresentableProtocol
├── {FeatureName}Presenter.swift      ← ViewModel mapping + ViewModels
├── ServiceMap+{FeatureName}.swift    ← Extension on module ServiceMap
└── Views/                            ← Sub-views, cells, XIBs (optional)
```

---

## 1. Protocols File (all in one file)

**File:** `Sources/Microboards/{FeatureName}/{FeatureName}Protocols.swift`

```swift
import UIKit

// MARK: - Inward (Board → Controller/Interactor)

/// Messages pushed inward from Board to Interactor
protocol {FeatureName}Controllable: AnyObject {
    // Define commands Board can push into the Interactor
    // Often empty — used as a type-safe watched content marker
}

// MARK: - Outward (ViewController → Board)

/// ViewController sends direct user actions to Board
protocol {FeatureName}ActionDelegate: AnyObject {
    func close(_ isDone: Bool)
    func exitFlow()
    // Direct UI actions that affect board-level navigation
}

/// Interactor sends business-level events to Board
protocol {FeatureName}ControlDelegate: AnyObject {
    func loadData()
    func performCompletion(_ isDone: Bool)
    func presentChildBoard(with data: SomeData)
    // Domain-driven events from Interactor → Board
}

/// Combined delegate for convenience (Board conforms to this)
protocol {FeatureName}Delegate: {FeatureName}ActionDelegate, {FeatureName}ControlDelegate {}

// MARK: - View Interface

/// Type-safe handle for the ViewController
protocol {FeatureName}UserInterface: UIViewController {}

/// Output of Builder.build()
struct {FeatureName}Interface {
    let userInterface: {FeatureName}UserInterface
    let controller: {FeatureName}Controllable
}

// MARK: - Builder Protocol

/// DI contract for the Board to use
protocol {FeatureName}Buildable {
    func build(withDelegate delegate: {FeatureName}Delegate?, input: {FeatureName}Input) -> {FeatureName}Interface
}
```

**Rules:**
- ALL protocols for one microboard live in **one** `Protocols.swift` file
- `Controllable` = what Board can push INTO the Interactor (inward)
- `ActionDelegate` = what ViewController pushes OUT to Board (direct UI actions)
- `ControlDelegate` = what Interactor pushes OUT to Board (domain events)
- `Delegate` = combined; Board conforms to this
- `Interactable` protocol is defined in **ViewController** file (see below)
- Pure navigation/action intents must go directly `ViewController -> ActionDelegate(Board)`; do not route through Interactor when Interactor only forwards
- Interactor must not own or inject `actionDelegate`; Interactor communicates outward only via `delegate: ControlDelegate`

---

## 2. Interactor

**File:** `Sources/Microboards/{FeatureName}/{FeatureName}Interactor.swift`

```swift
import Foundation

// MARK: - Presentable Protocol (defined here, used by Presenter)

/// Interactor → Presenter: domain model → view model
protocol {FeatureName}Presentable: AnyObject {
    func present{State}(_ model: {DomainModel})
    func presentOverlayLoading()
    func dismissOverlayLoading()
    func presentError(_ error: any Error)
}

// MARK: - Interactor

final class {FeatureName}Interactor {
    // Board reference (weak to avoid retain cycle)
    weak var delegate: {FeatureName}ControlDelegate!

    private let presenter: {FeatureName}Presentable
    private let input: {FeatureName}Input
    private let someUseCase: SomeUseCase

    init(presenter: {FeatureName}Presentable,
         input: {FeatureName}Input,
         someUseCase: SomeUseCase) {
        self.presenter = presenter
        self.input = input
        self.someUseCase = someUseCase
    }
}

// MARK: - As Interactor (View-facing)

extension {FeatureName}Interactor: {FeatureName}Interactable {
    func didBecomeActive() {
        delegate?.loadData()
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await someUseCase.execute()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.present{State}(result)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    delegate.closeDueToError()
                }
            }
        }
    }

    func userDidTapSubmit(with data: SomeData) {
        Task { [weak self] in
            guard let self else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                presenter.presentOverlayLoading()
            }
            do {
                try await someUseCase.submit(data)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.dismissOverlayLoading()
                    delegate.performCompletion(true)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.dismissOverlayLoading()
                    presenter.presentError(error)
                }
            }
        }
    }
}

// MARK: - As Controller (Board-facing inward)

extension {FeatureName}Interactor: {FeatureName}Controllable {}
```

**Rules:**
- `{FeatureName}Presentable` protocol is defined **inside** the Interactor file
- `delegate` is `weak` — Board holds Interactor, Interactor holds weak Board ref
- Async work: always `Task { [weak self] in ... }` + `await MainActor.run { [weak self] in ... }`
- Interactor also conforms to `{FeatureName}Controllable` — serves as the `controller` in the `Interface` struct
- `didBecomeActive()` is the VIP lifecycle entry point (called by ViewController's `viewDidLoad`)
- Interactor handles business logic and state transitions only; never act as a pass-through router for direct UI intents
- Interactor must not reference `ActionDelegate`

---

## 3. Presenter

**File:** `Sources/Microboards/{FeatureName}/{FeatureName}Presenter.swift`

```swift
import Foundation
import UIKit

// MARK: - View Protocol (defined here)

protocol {FeatureName}Viewable: AnyObject {
    func setState(_ state: {FeatureName}State)
    func showHUDLoading()
    func hideHUDLoading()
    func showErrorSnackMessage(_ message: String)
}

// MARK: - Presenter

final class {FeatureName}Presenter {
    weak var view: {FeatureName}Viewable!
}

extension {FeatureName}Presenter: {FeatureName}Presentable {
    func present{State}(_ model: {DomainModel}) {
        let viewModel = map(model)
        view?.setState(.loaded(viewModel))
    }

    func presentOverlayLoading() {
        view?.showHUDLoading()
    }

    func dismissOverlayLoading() {
        view?.hideHUDLoading()
    }

    func presentError(_ error: any Error) {
        view?.showErrorSnackMessage(error.localizedDescription)
    }
}

// MARK: - Private mapping

private extension {FeatureName}Presenter {
    func map(_ model: {DomainModel}) -> {FeatureName}ViewModel {
        {FeatureName}ViewModel(
            title: model.name.uppercased(),
            // ... all formatting here
        )
    }
}

// MARK: - View Models (defined here)

enum {FeatureName}State {
    case loading
    case loaded({FeatureName}ViewModel)
    case error(String)
}

struct {FeatureName}ViewModel {
    let title: String
    let subtitle: String?
    // ...
}
```

**Rules:**
- `{FeatureName}Viewable` protocol defined **inside** Presenter file
- ViewModels (structs/enums) defined **inside** Presenter file
- `weak var view` — always weak
- All string formatting, localization, conditional display logic lives here

---

## 4. ViewController (Humble Object)

**File:** `Sources/Microboards/{FeatureName}/{FeatureName}ViewController.swift`

```swift
import UIKit

// MARK: - Interactable Protocol (defined here, in ViewController file)

/// ViewController → Interactor: user interaction messages
protocol {FeatureName}Interactable {
    func didBecomeActive()
    func userDidTapSubmit(with data: SomeData)
    // All actions the user can trigger
}

// MARK: - ViewController

final class {FeatureName}ViewController: UIViewController, {FeatureName}UserInterface {

    // MARK: - Dependencies (wired by Builder)
    weak var actionDelegate: {FeatureName}ActionDelegate!  // weak — Board
    var interactor: {FeatureName}Interactable!

    // MARK: - UI (IBOutlets or lazy vars)
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var submitButton: UIButton!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        interactor.didBecomeActive()
    }

    // MARK: - {FeatureName}Viewable (rendering only)
    func setState(_ state: {FeatureName}State) {
        switch state {
        case .loading:
            submitButton.isEnabled = false
        case .loaded(let vm):
            titleLabel.text = vm.title
            submitButton.isEnabled = true
        case .error:
            break
        }
    }

    func showHUDLoading() { /* show spinner */ }
    func hideHUDLoading() { /* hide spinner */ }
    func showErrorSnackMessage(_ message: String) { /* show snack */ }

    // MARK: - User Actions (forward to interactor or actionDelegate)
    @IBAction func didTapSubmit(_ sender: UIButton) {
        interactor.userDidTapSubmit(with: getData())
    }

    @IBAction func didTapClose(_ sender: UIButton) {
        actionDelegate.close(false)   // navigation → goes to Board
    }
}

// MARK: - {FeatureName}Viewable conformance
extension {FeatureName}ViewController: {FeatureName}Viewable {}
```

**Rules:**
- `{FeatureName}Interactable` protocol defined **in ViewController file** (not Protocols.swift)
- `actionDelegate` is `weak` — points to Board
- `interactor` is non-weak (ViewController owns it conceptually via Board's watch)
- ViewController loads from **Storyboard** by convention (see Builder below)
- ZERO logic — only render and forward

---

## 5. Builder

**File:** `Sources/Microboards/{FeatureName}/{FeatureName}Builder.swift`

```swift
import UIKit

struct {FeatureName}Builder: {FeatureName}Buildable {
    // Dependencies from Board/shared component
    let someRepository: SomeRepository
    let tracker: TrackerService

    func build(withDelegate delegate: {FeatureName}Delegate?, input: {FeatureName}Input) -> {FeatureName}Interface {
        // 1. Load ViewController from Storyboard (convention in this codebase)
        let viewController = {FeatureName}ViewController()

        // 2. Wire delegate (Board) into ViewController
        viewController.actionDelegate = delegate

        // 3. Build services and use cases
        let apiService = RESTSomeService(httpClient: SomeAPI.default)
        let useCase = SomeUseCaseInteractor(repository: someRepository, service: apiService)

        // 4. Build Presenter and wire view
        let presenter = {FeatureName}Presenter()
        presenter.view = viewController

        // 5. Build Interactor and wire
        let interactor = {FeatureName}Interactor(
            presenter: presenter,
            input: input,
            someUseCase: useCase
        )
        interactor.delegate = delegate   // Interactor → Board (weak)

        // 6. Wire interactor into ViewController
        viewController.interactor = interactor

        // 7. Return Interface (userInterface + controller for Board to watch)
        return {FeatureName}Interface(
            userInterface: viewController,
            controller: interactor   // Interactor IS the Controllable
        )
    }
}
```

**Key pattern:** The `controller` in the returned `Interface` struct IS the `Interactor` (because Interactor conforms to `Controllable`). The Board then calls `watch(content: component.controller)` to track its lifecycle.

---

## Protocol Location Summary

| Protocol | Defined in | Conformed by |
|----------|-----------|--------------|
| `{Name}Interactable` | ViewController file | Interactor |
| `{Name}Presentable` | Interactor file | Presenter |
| `{Name}Viewable` | Presenter file | ViewController |
| `{Name}Controllable` | Protocols.swift | Interactor |
| `{Name}ActionDelegate` | Protocols.swift | Board |
| `{Name}ControlDelegate` | Protocols.swift | Board |
| `{Name}Delegate` | Protocols.swift | Board |
| `{Name}UserInterface` | Protocols.swift | ViewController |
| `{Name}Buildable` | Protocols.swift | Builder struct |

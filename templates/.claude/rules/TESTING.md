<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Testing Standards

> **Load this spec** when writing unit tests for Interactors, Presenters, UseCases, or Boards.

## Test Coverage Requirements

| Component | What to Test | Priority |
|-----------|-------------|----------|
| Interactor | User actions → UseCase calls → delegate/presenter calls | High |
| Presenter | Domain Model → ViewModel mapping (formatting, nil handling) | High |
| UseCaseInteractor | Business logic, error handling, repository calls | High |
| Board | Activation, output emission (if testable) | Medium |

---

## 1. Interactor Tests

The Interactor has TWO dependencies to mock: `presenter` and `delegate` (Board).

```swift
// Tests/Microboards/{Feature}/{Feature}InteractorTests.swift
import XCTest
@testable import {ModuleNamePlugins}

final class {Feature}InteractorTests: XCTestCase {

    var sut: {Feature}Interactor!
    var mockPresenter: Mock{Feature}Presenter!
    var mockDelegate: Mock{Feature}ControlDelegate!
    var mockUseCase: Mock{Feature}UseCase!

    override func setUp() {
        super.setUp()
        mockPresenter = Mock{Feature}Presenter()
        mockDelegate = Mock{Feature}ControlDelegate()
        mockUseCase = Mock{Feature}UseCase()
        sut = {Feature}Interactor(
            presenter: mockPresenter,
            input: {Feature}Input.stub(),
            someUseCase: mockUseCase
        )
        sut.delegate = mockDelegate
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        mockDelegate = nil
        mockUseCase = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_didBecomeActive_callsLoadData_and_fetchesData() async throws {
        // Given
        mockUseCase.fetchResult = .success(.stub())

        // When
        sut.didBecomeActive()
        await Task.yield()

        // Then
        XCTAssertTrue(mockDelegate.loadDataCalled)
        XCTAssertTrue(mockUseCase.fetchCalled)
        XCTAssertTrue(mockPresenter.presentStateCalled)
    }

    func test_didBecomeActive_whenFetchFails_callsClose() async throws {
        // Given
        mockUseCase.fetchResult = .failure(TestError.network)

        // When
        sut.didBecomeActive()
        await Task.yield()

        // Then
        XCTAssertTrue(mockDelegate.closeDueToErrorCalled)
        XCTAssertFalse(mockPresenter.presentStateCalled)
    }

    func test_submit_showsLoading_thenCallsDelegate() async throws {
        // Given
        mockUseCase.submitResult = .success(())

        // When
        sut.userDidTapSubmit(with: "data")
        await Task.yield()

        // Then
        XCTAssertTrue(mockPresenter.presentOverlayLoadingCalled)
        XCTAssertTrue(mockPresenter.dismissOverlayLoadingCalled)
        XCTAssertTrue(mockDelegate.performCompletionCalled)
    }

    func test_submit_whenFails_showsError() async throws {
        // Given
        mockUseCase.submitResult = .failure(TestError.network)

        // When
        sut.userDidTapSubmit(with: "data")
        await Task.yield()

        // Then
        XCTAssertTrue(mockPresenter.dismissOverlayLoadingCalled)
        XCTAssertTrue(mockPresenter.presentErrorCalled)
        XCTAssertFalse(mockDelegate.performCompletionCalled)
    }
}
```

### Mock ControlDelegate (Board mock)

```swift
final class Mock{Feature}ControlDelegate: {Feature}ControlDelegate {
    var loadDataCalled = false
    var performCompletionCalled = false
    var lastIsDone: Bool?
    var closeDueToErrorCalled = false

    func loadData() { loadDataCalled = true }
    func performCompletion(_ isDone: Bool) {
        performCompletionCalled = true
        lastIsDone = isDone
    }
    func closeDueToError() { closeDueToErrorCalled = true }
}
```

### Mock Presenter

```swift
final class Mock{Feature}Presenter: {Feature}Presentable {
    var presentStateCalled = false
    var lastDomainModel: {DomainModel}?
    var presentOverlayLoadingCalled = false
    var dismissOverlayLoadingCalled = false
    var presentErrorCalled = false
    var lastError: Error?

    func presentState(_ model: {DomainModel}) {
        presentStateCalled = true
        lastDomainModel = model
    }
    func presentOverlayLoading() { presentOverlayLoadingCalled = true }
    func dismissOverlayLoading() { dismissOverlayLoadingCalled = true }
    func presentError(_ error: any Error) {
        presentErrorCalled = true
        lastError = error
    }
}
```

---

## 2. Presenter Tests

```swift
final class {Feature}PresenterTests: XCTestCase {

    var sut: {Feature}Presenter!
    var mockView: Mock{Feature}View!

    override func setUp() {
        super.setUp()
        mockView = Mock{Feature}View()
        sut = {Feature}Presenter()
        sut.view = mockView
    }

    func test_presentState_mapsToCorrectViewModel() {
        // Given
        let model = {Aggregate}.stub(relatedCount: 3)

        // When
        sut.presentState(model)

        // Then
        XCTAssertNotNil(mockView.lastState)
        if case .loaded(let viewModel) = mockView.lastState {
            XCTAssertEqual(viewModel.items.count, 3)
            XCTAssertNotNil(viewModel.title)
        } else {
            XCTFail("Expected .loaded state")
        }
    }

    func test_presentError_showsSnackMessage() {
        // When
        sut.presentError(TestError.network)

        // Then
        XCTAssertTrue(mockView.showErrorSnackCalled)
        XCTAssertNotNil(mockView.lastErrorMessage)
    }

    func test_presentOverlayLoading_showsHUD() {
        sut.presentOverlayLoading()
        XCTAssertTrue(mockView.showHUDCalled)
    }

    func test_dismissOverlayLoading_hidesHUD() {
        sut.dismissOverlayLoading()
        XCTAssertTrue(mockView.hideHUDCalled)
    }
}

// Mock View
final class Mock{Feature}View: {Feature}Viewable {
    var lastState: {Feature}State?
    var showHUDCalled = false
    var hideHUDCalled = false
    var showErrorSnackCalled = false
    var lastErrorMessage: String?

    func setState(_ state: {Feature}State) { lastState = state }
    func showHUDLoading() { showHUDCalled = true }
    func hideHUDLoading() { hideHUDCalled = true }
    func showErrorSnackMessage(_ message: String) {
        showErrorSnackCalled = true
        lastErrorMessage = message
    }
}
```

---

## 3. UseCase Tests

```swift
final class {Action}UseCaseTests: XCTestCase {

    var sut: {Action}UseCaseInteractor!
    var mockRepository: Mock{Entity}Repository!
    var mockQueryService: Mock{Entity}QueryService!

    override func setUp() {
        super.setUp()
        mockRepository = Mock{Entity}Repository()
        mockQueryService = Mock{Entity}QueryService()
        sut = {Action}UseCaseInteractor(
            repository: mockRepository,
            queryService: mockQueryService
        )
    }

    func test_execute_whenServiceReturnsData_savesToRepository() async throws {
        // Given
        let aggregate = {Aggregate}.stub()
        mockQueryService.result = aggregate

        // When
        try await sut.execute()

        // Then
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertNotNil(mockRepository.lastSaved)
    }

    func test_execute_whenServiceReturnsNil_throwsError() async {
        // Given
        mockQueryService.result = nil

        // When / Then
        do {
            try await sut.execute()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(error as? {Module}Error, .notFound)
        }
    }
}

final class Mock{Entity}QueryService: {Entity}QueryService {
    var result: {Aggregate}?
    func get{Aggregate}() async throws -> {Aggregate}? { result }
}

final class Mock{Entity}Repository: {Entity}Repository {
    var saveCalled = false
    var lastSaved: {Aggregate}?
    // ... all protocol methods
    func save(_ aggregate: {Aggregate}) async {
        saveCalled = true
        lastSaved = aggregate
    }
    func getPrimary() async -> {Entity}? { nil }
    func saveSelection(_ selection: {Entity}Selection) async {}
    func getSelections() async -> [{Entity}Submission] { [] }
    func getRelated() async -> [{Entity}] { [] }
    func getMetadata() async -> {Metadata}? { nil }
}
```

---

## 4. Stub Factories

```swift
// Tests/Stubs/
extension {Feature}Input {
    static func stub() -> {Feature}Input {
        {Feature}Input(context: nil, completion: nil)
    }
}

extension {Aggregate} {
    static func stub(relatedCount: Int = 2) -> {Aggregate} {
        {Aggregate}(
            primary: {Entity}.stub(),
            related: (0..<relatedCount).map { {Entity}.stub(index: $0) },
            metadata: nil
        )
    }
}

extension {Entity} {
    static func stub(index: Int = 0) -> {Entity} {
        {Entity}(
            id: "stub-\(index)",
            name: "Item \(index)",
            imageURL: nil,
            tags: []
        )
    }
}

enum TestError: Error {
    case network
    case parsing
}
```

---

## 5. Test File Layout

```
{ModuleNamePlugins}Tests/
├── Microboards/
│   └── {Feature}/
│       ├── {Feature}InteractorTests.swift
│       └── {Feature}PresenterTests.swift
├── Services/
│   └── {Action}UseCaseTests.swift
├── Mocks/
│   ├── Mock{Feature}Presenter.swift
│   ├── Mock{Feature}ControlDelegate.swift
│   ├── Mock{Feature}View.swift
│   └── Mock{Entity}Repository.swift
└── Stubs/
    └── {Feature}Stubs.swift
```

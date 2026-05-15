<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SPEC: Service Layer (DDD)

> **Load this spec** when creating Domain models, Use Cases, Repositories, or Infrastructure implementations.
> Reference: *Modern large-scale iOS app development* — Domain-driven Layered pillar.
> Companion specs: `.claude/rules/LAYERING.md` (3-layer dependency rule), `.claude/rules/EXAMPLES_SERVICE.md` (concrete skeleton).

## Layer Structure

```
Sources/Services/
├── Domain/
│   ├── Models/          ← Pure Swift value types (structs/enums)
│   ├── Repositories/    ← Repository protocols
│   └── Services/        ← Domain service protocols (non-repository)
├── Application/
│   └── {Action}UseCase.swift  ← Protocol + Interactor (implementation)
├── Infra/
│   ├── REST{Entity}Service.swift              ← Networking (HTTP client)
│   ├── {Entity}MemoryStorageRepository.swift  ← In-memory storage
│   └── {Entity}DBRepository.swift             ← Persistent storage
└── Tracking/
    ├── TrackingEvent+Extensions.swift    ← Analytics event definitions
    └── TrackingParameters.swift          ← Analytics parameter structs
```

---

## 1. Domain Layer — Models

**File:** `Sources/Services/Domain/Models/{Feature}Models.swift`

```swift
// Pure Swift — no imports except Foundation for URL/Date
import Foundation

struct {Entity} {
    let id: String
    let name: String
    let imageURL: URL?
    let tags: [String]
}

struct {Aggregate} {
    let primary: {Entity}
    let related: [{Entity}]
    let metadata: {Metadata}?
}

// Typed state/selection enums
struct {Entity}Selection: Hashable, Equatable {
    enum Action: String {
        case liked = "LIKE"
        case disliked = "DISLIKE"
        case neutral = "NEUTRAL"
    }
    let id: String
    let action: Action

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// Shared value object (used across domain + presenter)
struct {SharedValueObject} {
    let content: String
    let attributes: [{SharedValueAttribute}]
}

struct {SharedValueAttribute} {
    let range: String
    let value: String
}

// Domain-level error
enum {Module}Error: Error {
    case notFound
    case invalidInput
}
```

**Rules:**
- ✅ Structs only (value types)
- ✅ Enums for typed states and selections
- ✅ `Hashable`/`Equatable` when needed for sets/comparison
- ✅ Error types defined here as `enum {Module}Error: Error`
- ❌ No Codable — DTOs live in Infra
- ❌ No UIKit, no Boardy

---

## 2. Domain Layer — Repository Protocols

**File:** `Sources/Services/Domain/Repositories/{Entity}Repository.swift`

```swift
protocol {Entity}Repository {
    func save(_ aggregate: {Aggregate}) async

    func getPrimary() async -> {Entity}?
    func saveSelection(_ selection: {Entity}Selection) async
    func getSelections() async -> [{Entity}Submission]

    func getRelated() async -> [{Entity}]
    func getMetadata() async -> {Metadata}?
}
```

---

## 3. Domain Layer — Service Protocols

**File:** `Sources/Services/Domain/Services/{Name}Service.swift`

```swift
// Query service (read-only, typically networked)
protocol {Entity}QueryService {
    func get{Aggregate}() async throws -> {Aggregate}?
}

// Submit service (write, typically networked)
protocol {Entity}SubmitService {
    func submit(_ submissions: [{Entity}Submission]) async throws
}

// Reward / side-effect service
protocol {Entity}RewardService {
    func claimReward() async throws -> {Entity}Reward
}
```

---

## 4. Application Layer — Use Cases

**Pattern:** Each use case has a **protocol** and a concrete **Interactor** class (suffixed with `Interactor` — not to be confused with the VIP Interactor).

**File:** `Sources/Services/Application/{Action}UseCase.swift`

```swift
import Foundation

// MARK: - Use Case Protocol
protocol Load{Aggregate}UseCase {
    func load() async throws
}

// MARK: - Use Case Implementation (named *UseCaseInteractor)
final class Load{Aggregate}UseCaseInteractor: Load{Aggregate}UseCase {
    let queryService: {Entity}QueryService
    let repository: {Entity}Repository

    init(repository: any {Entity}Repository,
         queryService: any {Entity}QueryService) {
        self.queryService = queryService
        self.repository = repository
    }

    func load() async throws {
        if let aggregate = try await queryService.get{Aggregate}() {
            await repository.save(aggregate)
        } else {
            throw {Module}Error.notFound
        }
    }
}
```

### Use Case with state + multiple methods

```swift
protocol {Feature}UseCase {
    func load() async -> {Aggregate}?
    func respond(with selection: {Entity}Selection) async
    func submit() async throws
    func getMetadata() async -> {Metadata}?
}

final class {Feature}UseCaseInteractor: {Feature}UseCase {
    private let repository: {Entity}Repository
    private let submitService: {Entity}SubmitService

    init(repository: any {Entity}Repository,
         submitService: any {Entity}SubmitService) {
        self.repository = repository
        self.submitService = submitService
    }

    func load() async -> {Aggregate}? {
        await repository.getPrimary().map { /* assemble aggregate */ }
    }

    func respond(with selection: {Entity}Selection) async {
        await repository.saveSelection(selection)
    }

    func submit() async throws {
        let submissions = await repository.getSelections()
        try await submitService.submit(submissions)
    }

    func getMetadata() async -> {Metadata}? {
        await repository.getMetadata()
    }
}
```

### Naming Convention

| Class suffix | Role |
|-------------|------|
| `*UseCase` | Protocol name |
| `*UseCaseInteractor` | Concrete implementation of the use case |

(Not to confuse with the VIP `*Interactor` — the suffix `UseCaseInteractor` signals this is a service-layer object.)

---

## 5. Infrastructure Layer

### In-Memory Repository

```swift
// Sources/Services/Infra/{Entity}MemoryStorageRepository.swift
final class {Entity}MemoryStorageRepository: {Entity}Repository {
    private var aggregate: {Aggregate}?
    private var selections: [{Entity}Selection] = []

    func save(_ aggregate: {Aggregate}) async {
        self.aggregate = aggregate
    }

    func getPrimary() async -> {Entity}? {
        aggregate?.primary
    }

    func saveSelection(_ selection: {Entity}Selection) async {
        selections.removeAll { $0.id == selection.id }
        selections.append(selection)
    }

    func getSelections() async -> [{Entity}Submission] {
        guard let related = aggregate?.related else { return [] }
        return selections.compactMap { selection in
            guard let entity = related.first(where: { $0.id == selection.id }) else { return nil }
            return {Entity}Submission(selection: selection, code: entity.id, tags: entity.tags)
        }
    }

    func getRelated() async -> [{Entity}] { aggregate?.related ?? [] }
    func getMetadata() async -> {Metadata}? { aggregate?.metadata }
}
```

### REST Service (split by concern using extensions)

```swift
// Sources/Services/Infra/REST{Entity}Service.swift — base class
final class REST{Entity}Service {
    let httpClient: HTTPClient
    init(httpClient: HTTPClient) { self.httpClient = httpClient }
}

// Sources/Services/Infra/REST{Entity}Service+{Concern}.swift — extension per protocol
extension REST{Entity}Service: {Entity}QueryService {
    func get{Aggregate}() async throws -> {Aggregate}? {
        let dto: {Aggregate}DTO = try await httpClient.request(
            endpoint: {Entity}Endpoints.get
        )
        return dto.toDomain()
    }
}

extension REST{Entity}Service: {Entity}SubmitService {
    func submit(_ submissions: [{Entity}Submission]) async throws {
        let request = {Entity}SubmitRequest(submissions: submissions)
        try await httpClient.request(endpoint: {Entity}Endpoints.submit(request))
    }
}
```

---

## 6. Tracking Layer

Analytics lives in `Sources/Services/Tracking/` as a parallel concern:

```swift
// TrackingEvent+Extensions.swift
extension TrackingEvent {
    static func {feature}Started(id: String) -> TrackingEvent {
        TrackingEvent(name: "{feature}_started", parameters: ["id": id])
    }
}

// {ModuleName}AnalyticsTracker.swift (Infra wrapper — rename with your module prefix)
final class {ModuleName}AnalyticsTracker: ExternalTrackerProtocol {
    func track(_ event: TrackingEvent) {
        // Wrap Firebase / internal analytics SDK
    }
}
```

---

## Dependency Flow Summary

```
UseCase (Application)
    ├── depends on → Repository (Domain protocol)
    │                   └── implemented by → MemoryStorageRepository (Infra)
    └── depends on → Service (Domain protocol)
                        └── implemented by → RESTService (Infra)

VIP Interactor
    └── depends on → UseCase (Application protocol)

Builder
    ├── instantiates → RESTService (Infra)
    ├── receives → Repository (shared from ModulePlugin)
    └── creates → UseCaseInteractor (Application)
```

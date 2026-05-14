<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# SDK_FIRST — Platform-Native Dependency Standard

> **Load this spec** when adding dependencies, choosing frameworks, introducing infrastructure adapters, or reviewing third-party usage.
> Reference: *Modern large-scale iOS app development* — SDK-first pillar.

---

## Core Rule

Prefer first-party platform SDKs and language-standard libraries before adding third-party dependencies.

Use third-party libraries only when they provide clear product or engineering value that cannot be reasonably achieved with built-in SDKs.

---

## Decision Order

1. Use Swift, Foundation, UIKit, Swift Concurrency, URLSession, Codable, XCTest, and other first-party SDKs when sufficient.
2. Use existing project-local abstractions already present in the app or module.
3. Add or keep a third-party dependency only when the native option is incomplete, risky, or materially more expensive.
4. Wrap third-party APIs at module boundaries so Domain and Business Application layers do not depend on vendor types.

---

## Allowed Third-Party Dependency Criteria

A third-party dependency is acceptable when at least one condition is true:

- It is already part of the architecture contract, such as Boardy for board composition.
- It provides infrastructure integration the platform SDK does not provide directly.
- It replaces substantial custom code with a stable, well-maintained implementation.
- It is isolated behind Domain protocols or Infrastructure adapters.

---

## Layering Rules

| Layer | Third-party rule |
|------|------------------|
| Domain | No third-party imports. Foundation only when needed. |
| Business Application | Avoid third-party imports except architecture primitives already approved by the stack. |
| Infrastructure & UI | Third-party SDKs allowed only behind adapters, DTOs, repositories, services, or UI components. |
| Interface Module | Keep dependency surface minimal; expose plain Swift types and Boardy IO contracts only. |

---

## Dependency Review Checklist

Before adding a dependency:

- [ ] Native SDK alternative was checked.
- [ ] Existing project abstraction was checked.
- [ ] Dependency does not leak into Domain models or repository protocols.
- [ ] Dependency does not force consumers to import Implementation Modules.
- [ ] Public IO types remain stable and vendor-neutral.
- [ ] Podspec / package entry uses dependency name only; local paths stay in app-level dependency configuration.
- [ ] Build impact and maintenance ownership are acceptable.

---

## Anti-Patterns

| Smell | Fix |
|------|-----|
| Adding a library for a small helper | Write local Swift code. |
| Domain imports vendor SDK | Move vendor type to Infrastructure and map to Domain model. |
| Public IO exposes SDK-specific DTO | Expose plain Swift input/output model. |
| Feature module imports another module's Plugins target | Depend on Interface Module only. |
| ViewController directly calls analytics/network SDK | Route through Interactor → UseCase → Domain protocol → Infra adapter. |

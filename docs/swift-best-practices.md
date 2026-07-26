# Swift Best Practices

Adapted from [Lickability/swift-best-practices](https://github.com/Lickability/swift-best-practices) for this project (SwiftUI macOS app, SwiftPM, MVVM). These rules apply to all AI coding agents (Claude Code, Antigravity) and human contributors.

## Architecture (MVVM)

- **Model** — represents application data, independent of UI. Prefer immutable `struct`s; recreate the model when data changes instead of mutating (mutable models invite race conditions). Models do **not** fetch from the network or persistence — that is a Service's job.
- **View** — renders content and handles user interaction. Styling and layout live here. Views communicate user interaction upward via closures or by calling view-model methods; presentation logic does not live in views.
- **ViewModel** — the single point of configuration for displayable properties. Transforms model data into display-ready values (e.g. `Date` → localized string). Interaction handling belongs to the view; transformation logic belongs to the view model.
- **Services** (this project's controller layer) — networking (`GeminiLiveClient`), persistence (`SessionStorageService`, `KeychainService`), system integration (`AudioEngineService`, `ScreenCaptureService`, `GlobalHotkeyService`). Each service has a protocol (`*Protocol.swift`) plus a mock (`Mocks/Mock*.swift`) for dependency injection in tests.

## Access Control

- **Default to `private`.** Anything that can be private should be. Use `private(set)` when reads must be external but writes internal.
- Never write `internal` explicitly — it's the default.
- Only use `public` when a symbol must be used outside its defining module (e.g. exported from the `AIEnglishTutor` library target to `AIEnglishTutorApp`).
- Declare classes `final` unless subclassing is intended.

## Naming

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/#naming).
- Include type information in UI component names to disambiguate at usage sites: `nameTextField`, not `name`; `SettingsView` / `settingsView`, not `Settings` / `settings`.

## Optionals

- Avoid optionals when a non-optional design is possible.
- Never make `Bool` optional — model tri-state with a well-named `enum`.
- Avoid optional `Array`s — use empty instead, unless `nil` carries distinct meaning.
- Unwrap safely: prefer `if let`; use `guard let` + early return when a value is required.

## Documentation & Comments

- Everything `internal` or higher requires `///` documentation (exception: protocol conformances and `override`s). Documenting `private` symbols is optional.
- Enums: one doc line on the type, plus a doc line per case; document associated values as parameters.
- Document extensions with a comment describing the functionality they add.
- Parameter docs must match the order of parameters in the API.
- Use inline `//` comments only to explain edge cases or unfamiliar patterns — prefer clear naming over comments.

## File Organization

- One major type declaration per file; supporting types (its protocol, nested types, private extensions) may share the file.
- Order within a file: imports → protocols tied to the major type → the major type → nested types → properties (protocol, public, internal, private) → functions in the same order → protocol-conformance extensions → private extensions.
- Initializers first within each group; `deinit` directly after the last initializer.
- Use `// MARK: -` to group by conformance/inheritance source; only needed when a file has overrides or conformances.
- Imports: system frameworks first, then third-party, then our own; no blank lines between them; `@testable` imports last.
- General-purpose extensions live in their own file named `<Type>+<Purpose>.swift` (e.g. `Array+MergeSort.swift`).

## SwiftUI

- Place `body` after the `init` (or after properties when there is no `init`) with a `// MARK: - View` above it.
- Group property wrappers of the same kind together (`@Binding`, `@State`, `@AppStorage`, `@StateObject`, …), followed by plain properties.
- `@State`, `@StateObject`, `@AppStorage` properties are `private`.
- Prefer synthesized member-wise initializers; mark `var` properties set at init `private(set)`. Write a manual `init` when it cleans up call sites (e.g. accepting `Binding<T>` parameters).
- Comment unclear modifiers to the right of the modifier; for modifiers with closures, comment at the top of the closure body.

## Object Communication

- **Delegation** — one-to-one communication initiated by the owner of the delegate; delegate properties are `weak`.
- **Closures** — also one-to-one, but can capture state; convenient for callbacks (this project's services use closure callbacks like `onFrame`, `onPCMData`, `onTranscript`).
- **Notifications / publishers** — one-to-many, one-way broadcast to any interested subscriber (`NotificationCenter`, Combine publishers, `@Published`).
- Pick the narrowest mechanism that fits: prefer closures/delegation over broadcast when there is exactly one listener.

## Protocols & Dependency Injection

- Use protocols to define common interfaces, wrap third-party dependencies, and enable test doubles.
- Services are injected as protocol types so unit tests can substitute mocks (see `Sources/AIEnglishTutor/Mocks/`).

## Assets

- Colors and images known at compile time belong in asset catalogs (system colors excepted), organized in folders; colors should come from a design system to keep dark mode and tweaks manageable.
- Avoid image/color literals in code; avoid ad-hoc one-off colors.

## Project Organization

- Organize folders first by feature, then by architecture component when a feature grows past ~5 files (this project groups by component: `Models/`, `Services/`, `ViewModels/`, `Views/`, `Mocks/`).
- App entry-point files live in their own target (`Sources/AIEnglishTutorApp/`); static resources (e.g. `Info.plist`, asset catalogs) stay grouped separately from feature code.

## Default Parameter Values

- Prefer default parameter values over convenience overloads; the default should be the most common case, and it must be documented.

## Custom Operators

- Avoid custom operators. Overload sparingly (e.g. `Equatable`), implemented in an extension on the type it operates on.

## Zero Usage

- Primitives use literal `0` (`let count: Int = 0`); non-primitives use `.zero` (`let point: CGPoint = .zero`).

## Localization

- All user-facing text goes through `NSLocalizedString` (or `String(localized:)`), keyed by the English text, with a `comment` detailed enough for a translator without context.
- Use localized formatter APIs for numbers and dates.

## Testing

- Unit tests verify a single unit of work (XCTest). Inject mock services rather than touching real network/keychain/audio.
- Don't test default `Codable` behavior — only test custom `encode(to:)` / `init(from:)` implementations.
- Integration tests use real implementations together; keep them separate from unit tests (see `Tests/AIEnglishTutorTests/IntegrationTests.swift` and `E2ETests/`).

## TODOs

- Use `TODO` sparingly and always with a link to the tracking issue. Never use `FIXME` or other markers — one marker keeps unfinished work searchable.
- Single-line `//` comments only.

## Formatting

- Xcode defaults: 4-space indentation, spaces not tabs.
- Resolve all SwiftLint warnings before opening a PR (if SwiftLint is configured); disable a rule only with `// swiftlint:disable:this` plus a comment explaining why.

---

### Intentionally omitted from the upstream guide

- **Interface Builder** — this project has no storyboards/nibs; UI is 100% SwiftUI.
- **UIKit-specific guidance** (target-action, `IBOutlet` ordering, `UITableViewDataSource` patterns) — not applicable on this SwiftUI macOS app; if AppKit interop is needed, apply the same MARK/organization rules.
- **ViewStore pattern** — a Lickability-specific Composable-Architecture-style package; this project uses plain MVVM with `AppViewModel`. Revisit only if view-level state grows complex enough to warrant it.

# Contributing to WaterLogger

Thanks for taking the time to contribute. This document explains how to get started and what to keep in mind.

## Ground rules

- WaterLogger is permanently free: no ads, no IAP, no analytics. PRs that add any of these will be closed.
- Keep the dependency list at zero. If a feature genuinely cannot be done without a library, open an issue to discuss it first.
- Follow the existing architecture (see `CLAUDE.md`). In particular: `@Observable` view models, SwiftData persistence, business logic out of views.

## Getting started

1. Fork the repository and clone your fork.
2. Open `WaterLogger.xcodeproj` in Xcode 16 or later.
3. Set your own development team in *Signing & Capabilities* — you won't be able to run on device without it.
4. Build and run. There are no package dependencies to resolve.

## How to contribute

### Reporting a bug

Open a GitHub issue with:
- iOS version and device (or simulator) model
- Steps to reproduce
- What you expected vs. what happened
- Any relevant screenshots or logs

### Suggesting a feature

Open an issue describing the problem you're trying to solve before writing any code. This keeps effort from being wasted on PRs that don't fit the project's direction.

### Submitting a pull request

1. Create a branch off `main` with a descriptive name (`fix/notification-window-edge-case`, `feature/streak-counter`).
2. Make your changes, following the code style below.
3. Add or update unit tests for any logic you touch.
4. Make sure the project builds cleanly (`Cmd+B`) and all tests pass (`Cmd+U`).
5. Open a PR against `main` with a clear description of what changed and why.

## Code style

- **Swift only** — no Objective-C.
- 4-space indentation, no tabs.
- PascalCase for types, camelCase for properties and methods.
- `@Observable` for all view models — never `ObservableObject` or `@StateObject`.
- No force unwrapping (`!`) unless the compiler cannot prove safety and a comment explains why.
- Use `async`/`await` and Swift concurrency; avoid Combine.
- Localise all user-facing strings with `LocalizedStringKey` even if only English ships today.
- No `// TODO` or commented-out code in merged PRs.

## Architecture cheat sheet

| Concern              | Where it lives                  |
|----------------------|---------------------------------|
| UI                   | `Views/`                        |
| State & presentation | `ViewModels/` (`@Observable`)   |
| Persistence          | SwiftData `@Model` in `Models/` |
| HealthKit            | `HealthKitService` actor        |
| Notifications        | `NotificationService` actor     |

Nothing outside `NotificationService` should import or call `UNUserNotificationCenter`.
Nothing outside `HealthKitService` should import or call `HealthKit`.

## Testing

- Unit tests live in `WaterLoggerTests/`.
- Use the Swift Testing framework (`import Testing`).
- Mock `HKHealthStore` and `UNUserNotificationCenter` — don't rely on real system services in tests.
- UI tests are currently out of scope; don't add them unless discussed first.

## Commit messages

Use the imperative mood in the subject line, 72 characters max:

```
Add streak counter to TodayView
Fix notification not firing after midnight window reset
Refactor HealthKitService to reduce actor hops
```

No emojis, no ticket numbers in the subject (reference issues in the body if needed).

## License

By submitting a pull request you agree that your contribution will be licensed under the [Apache 2.0 License](LICENSE).

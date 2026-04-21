# WaterLogger

A 100% free iOS water intake reminder app with adaptive scheduling and HealthKit integration. No ads, no in-app purchases, no tracking — ever.

## What makes it different

Most reminder apps ping you on a fixed schedule. WaterLogger recalculates the next reminder dynamically after every intake log:

```
remaining ml ÷ remaining hours in your active window = next interval
```

If you drink a large glass at noon, your next reminder is pushed back accordingly. If you fall behind, it comes sooner. The interval is always capped between 30 minutes and 2 hours so it stays useful without being annoying.

## Features

- **Progress ring** — shows effective ml consumed vs. your daily goal
- **Beverage-aware hydration** — coffee, juice, soda, and herbal tea each carry a hydration coefficient so your progress reflects actual hydration, not just volume
- **Adaptive reminders** — dynamic scheduling based on remaining goal and remaining window time
- **HealthKit sync** — reads and writes `dietaryWater` samples; works seamlessly with Apple Watch and other apps
- **7-day history** — bar chart with a goal line overlay, tappable bars for daily breakdowns
- **Custom containers** — save your favourite cup/bottle sizes as presets
- **Configurable active window** — set a wake-up and wind-down time; no reminders outside that range

## Hydration coefficients

| Beverage   | Coefficient |
|------------|-------------|
| Water      | 1.00        |
| Herbal tea | 1.00        |
| Juice      | 0.90        |
| Soda       | 0.85        |
| Coffee     | 0.80        |
| Alcohol    | 0.00        |

## Requirements

- iOS 18.0+
- iPhone (iPad layout not optimised in v1)
- Xcode 16+ to build from source

## Tech stack

| Layer         | Technology                          |
|---------------|-------------------------------------|
| UI            | SwiftUI                             |
| Architecture  | MVVM with `@Observable`             |
| Persistence   | SwiftData                           |
| Health        | HealthKit (`HKHealthStore`)         |
| Notifications | `UserNotifications` (local only)    |
| Charts        | Swift Charts                        |
| Dependencies  | None (Swift Package Manager)        |

## Building

1. Clone the repo
2. Open `WaterLogger.xcodeproj` in Xcode
3. Select your development team in *Signing & Capabilities*
4. Run on a device or simulator (HealthKit requires a real device for full functionality)

No package resolution step needed — there are no third-party dependencies.

## Privacy

WaterLogger collects nothing. There is no analytics SDK, no crash reporter phoning home, and no account system. All data lives on your device and, optionally, in your personal iCloud Health database.

## License

Apache 2.0 — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

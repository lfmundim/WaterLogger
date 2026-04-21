import SwiftUI
import SwiftData

/// The app entry point, identified by `@main`.
///
/// `WaterLoggerApp` configures the SwiftData `ModelContainer` once at launch and
/// injects it into the view hierarchy via `.modelContainer(...)`. Any view or
/// view model that needs SwiftData access can then read it with
/// `@Environment(\.modelContext)`.
@main
struct WaterLoggerApp: App {
    /// The shared SwiftData container, created once for the lifetime of the app.
    ///
    /// The `Schema` lists every `@Model` type so SwiftData knows which tables to
    /// create. `isStoredInMemoryOnly: false` means data is written to disk in the
    /// app's Documents directory and survives app restarts.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            IntakeEntry.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// The root scene. `WindowGroup` is the standard single-window scene type for iOS apps.
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// The root tab bar that hosts the three main screens.
///
/// Each tab is a separate `View` with its own view model lifecycle, so navigating
/// between tabs does not reset state within a tab.
struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label(String(localized: "Today"), systemImage: "drop.fill")
                }
            HistoryView()
                .tabItem {
                    Label(String(localized: "History"), systemImage: "chart.bar.fill")
                }
            SettingsView()
                .tabItem {
                    Label(String(localized: "Settings"), systemImage: "gearshape.fill")
                }
        }
    }
}

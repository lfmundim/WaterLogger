import SwiftUI
import SwiftData

@main
struct WaterLoggerApp: App {
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

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

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

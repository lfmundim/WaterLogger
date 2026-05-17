import SwiftUI
import SwiftData

@main
struct WaterLoggerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([IntakeEntry.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Color.iosBlue)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root view

struct RootView: View {
    @State private var splashDone = false

    var body: some View {
        if splashDone {
            MainTabView()
        } else {
            SplashView(onFinished: { splashDone = true })
                .transition(.opacity)
        }
    }
}

// MARK: - Main tab view

struct MainTabView: View {
    @State private var todayVM = TodayViewModel()

    var body: some View {
        TabView {
            TodayView()
                .environment(todayVM)
                .tabItem { Label("Today", systemImage: "drop.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

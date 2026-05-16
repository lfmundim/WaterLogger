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
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App tab

enum AppTab: CaseIterable {
    case today, history, settings

    var label: LocalizedStringKey {
        switch self {
        case .today:    return "Today"
        case .history:  return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:    return "drop.fill"
        case .history:  return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - MainTabView

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

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @State private var todayVM = TodayViewModel()

    // Tab bar pill height + spacing above home indicator
    private let tabBarTotalHeight: CGFloat = 54 + 8 + 16

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Background (extends behind status bar via internal .ignoresSafeArea) ──
            AppBackground()

            // ── Ambient glows ────────────────────────────────────────────────
            ambientGlows
                .allowsHitTesting(false)

            // ── Tab content (respects safe area naturally) ───────────────────
            Group {
                switch selectedTab {
                case .today:
                    TodayView()
                        .environment(todayVM)
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, tabBarTotalHeight)

            // ── Floating tab bar — clean 3-tab pill ──────────────────────────
            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 16)
                .zIndex(10)
        }
    }

    // MARK: - Subviews

    private var ambientGlows: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [Color.iosBlue.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 160
                )
                .frame(width: 320, height: 320)
                .position(x: geo.size.width / 2, y: 120)

                RadialGradient(
                    colors: [Color.iosBlue.opacity(0.06), .clear],
                    center: .center, startRadius: 0, endRadius: 110
                )
                .frame(width: 220, height: 220)
                .position(x: geo.size.width - 60, y: geo.size.height - 120)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Floating tab bar

struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(7)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color(hex: "101628").opacity(0.90)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.13), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let active = selectedTab == tab
        return Button { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16))
                    .foregroundStyle(active ? Color.iosBlue : Color.white.opacity(0.38))
                    .frame(width: 22, height: 22)
                Text(tab.label)
                    .font(.system(size: 10, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? Color.iosBlue : Color.white.opacity(0.38))
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                active
                    ? AnyView(Capsule().fill(Color.iosBlue.opacity(0.16)))
                    : AnyView(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

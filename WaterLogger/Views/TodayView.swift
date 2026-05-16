import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TodayViewModel.self) private var viewModel
    @State private var entryToDelete: IntakeEntry?
    @State private var showLog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.bottom, 28)

                ProgressRingView(
                    progress: viewModel.progress,
                    consumed: Int(viewModel.totalEffectiveMl),
                    goal: Int(viewModel.settings.dailyGoalMl)
                )
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)

                statusChips
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 36)

                intakeLogSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .task { await viewModel.load(context: modelContext) }
        .refreshable { await viewModel.load(context: modelContext) }
        .sheet(isPresented: $showLog) {
            LogEntryView(viewModel: viewModel)
                .presentationDetents([.height(580)])
                .presentationCornerRadius(30)
                .presentationBackground(Color(hex: "090e1c"))
                .presentationDragIndicator(.hidden)
        }
        .alert(
            "Delete Entry?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    Task { await viewModel.deleteEntry(entry, context: modelContext) }
                }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            if let entry = entryToDelete {
                Text("\(Int(entry.amountMl)) ml · \(String(localized: entry.beverageType.displayName))")
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Today")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .kerning(0.2)

            Spacer()

            // Glass + button — Apple Calendar/Passwords style
            Button { showLog = true } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(Color(red: 0.43, green: 0.43, blue: 0.47, opacity: 0.30))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                        .frame(width: 36, height: 36)

                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status chips

    private var statusChips: some View {
        HStack(spacing: 8) {
            // Next reminder chip
            if let date = viewModel.nextReminderDate {
                let mins = max(Int(date.timeIntervalSinceNow / 60), 0)
                if mins > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                        Group {
                            Text("Next in ") + Text("\(mins) min").foregroundColor(Color.iosBlue) + Text("")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCard(cornerRadius: 99)
                }
            }

            // Remaining / goal-reached chip
            if viewModel.remainingMl == 0 {
                Text("Goal reached!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "34d399"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCard(cornerRadius: 99, tint: Color(hex: "34d399"))
            } else {
                (
                    Text("\(Int(viewModel.remainingMl)) ")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    + Text("ml remaining")
                        .foregroundColor(.white.opacity(0.5))
                )
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCard(cornerRadius: 99)
            }
        }
    }

    // MARK: - Intake log

    private var intakeLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Text("Intake Log")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .kerning(0.9)

                Spacer()

                let count = viewModel.entries.count
                Text("\(count) \(count == 1 ? "entry" : "entries")")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 2)

            if viewModel.entries.isEmpty {
                emptyState
            } else {
                entriesList
                summaryCard
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nothing logged yet.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.38))
            Text("Tap + to log your first drink")
                .font(.system(size: 15))
                .foregroundStyle(Color.iosBlue.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .glassCard()
    }

    private var entriesList: some View {
        // Entries are already newest-first from the view model
        VStack(spacing: 8) {
            ForEach(viewModel.entries) { entry in
                entryCard(entry)
            }
        }
    }

    private var summaryCard: some View {
        HStack {
            Text("Remaining today")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(viewModel.remainingMl > 0
                 ? "\(Int(viewModel.remainingMl)) ml"
                 : "Done!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(viewModel.remainingMl > 0 ? Color.iosBlue : Color(hex: "34d399"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassCard()
        .padding(.top, 2)
    }

    // MARK: - Entry card

    private func entryCard(_ entry: IntakeEntry) -> some View {
        HStack(spacing: 12) {
            BevDotView(
                bevType: entry.beverageType,
                size: 38,
                emojiMode: viewModel.settings.emojiMode
            )

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(localized: entry.beverageType.displayName))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Int(entry.amountMl)) ml")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.42))
                }
                if entry.beverageType.hydrationCoefficient < 1 {
                    Text("\(Int(entry.effectiveMl)) ml effective (×\(entry.beverageType.hydrationCoefficient, specifier: "%.2g"))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.32))
                        .padding(.top, 1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(entry.date, style: .time)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.38))

                Button { entryToDelete = entry } label: {
                    Text("×")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.red.opacity(0.45))
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassCard(cornerRadius: 16)
    }
}

#Preview {
    ZStack {
        AppBackground()
        TodayView()
            .environment(TodayViewModel())
    }
    .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

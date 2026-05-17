import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TodayViewModel.self) private var viewModel
    @State private var entryToDelete: IntakeEntry?
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Progress ring section
                Section {
                    ProgressRingView(
                        progress: viewModel.progress,
                        consumed: Int(viewModel.totalEffectiveMl),
                        goal: Int(viewModel.settings.dailyGoalMl)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    // Status chips below the ring
                    statusChips
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // MARK: Intake log section
                Section {
                    if viewModel.entries.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.entries) { entry in
                            entryRow(entry)
                        }
                        .onDelete { offsets in
                            // Map offsets to entries for deletion
                            for idx in offsets {
                                let entry = viewModel.entries[idx]
                                entryToDelete = entry
                            }
                        }
                    }
                } header: {
                    let count = viewModel.entries.count
                    Text("Intake Log · \(count) \(count == 1 ? "entry" : "entries")")
                }

                // MARK: Remaining section (only when there are entries)
                if !viewModel.entries.isEmpty {
                    Section {
                        LabeledContent("Remaining today") {
                            Text(viewModel.remainingMl > 0
                                 ? "\(Int(viewModel.remainingMl)) ml"
                                 : "Done!")
                                .fontWeight(.semibold)
                                .foregroundStyle(viewModel.remainingMl > 0 ? Color.iosBlue : Color(hex: "34d399"))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
                }
            }
            .task { await viewModel.load(context: modelContext) }
            .refreshable { await viewModel.load(context: modelContext) }
            .sheet(isPresented: $showLog) {
                LogEntryView(viewModel: viewModel)
                    .presentationDetents([.height(580)])
                    .presentationCornerRadius(30)
                    .presentationBackground(Color(hex: "090e1c"))
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
                            .foregroundStyle(.secondary)
                        Text("Next in \(mins) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
            }

            // Remaining / goal-reached chip
            if viewModel.remainingMl == 0 {
                Text("Goal reached!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "34d399"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            } else {
                Text("\(Int(viewModel.remainingMl)) ml remaining")
                    .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nothing logged yet.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text("Tap + to log your first drink")
                .font(.system(size: 15))
                .foregroundStyle(Color.iosBlue.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Entry row

    private func entryRow(_ entry: IntakeEntry) -> some View {
        HStack(spacing: 12) {
            BevDotView(
                bevType: entry.beverageType,
                size: 36,
                emojiMode: viewModel.settings.emojiMode
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: entry.beverageType.displayName))
                    .font(.body.weight(.medium))
                if entry.beverageType.hydrationCoefficient < 1 {
                    Text("\(Int(entry.effectiveMl)) ml effective")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.amountMl)) ml")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.iosBlue)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TodayView()
        .environment(TodayViewModel())
        .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

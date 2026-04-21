import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()
    @State private var showingLogEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    progressSection
                    entryList
                }
                .padding()
            }
            .navigationTitle(String(localized: "Today"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingLogEntry) {
                LogEntryView(viewModel: viewModel, settings: viewModel.settings)
            }
            .task {
                await viewModel.load(context: modelContext)
            }
            .refreshable {
                await viewModel.load(context: modelContext)
            }
        }
    }

    // MARK: - Subviews

    private var progressSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.progress)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.totalEffectiveMl))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("/ \(Int(viewModel.settings.dailyGoalMl)) ml")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            HStack(spacing: 24) {
                statCard(
                    title: String(localized: "Remaining"),
                    value: "\(Int(viewModel.remainingMl)) ml",
                    icon: "drop"
                )
                statCard(
                    title: String(localized: "Next reminder"),
                    value: nextReminderText,
                    icon: "bell"
                )
            }
        }
    }

    private var nextReminderText: String {
        guard let date = viewModel.nextReminderDate else {
            return String(localized: "—")
        }
        return date.formatted(.dateTime.hour().minute())
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Entries")
                .font(.headline)
                .padding(.horizontal, 4)

            if viewModel.entries.isEmpty {
                Text("No entries yet. Tap + to log your first drink!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.entries) { entry in
                        entryRow(entry)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteEntry(entry, context: modelContext)
                                    }
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func entryRow(_ entry: IntakeEntry) -> some View {
        HStack {
            Image(systemName: entry.beverageType.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.beverageType.displayName)
                    .font(.subheadline)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.amountMl)) ml")
                    .font(.subheadline).bold()
                if entry.beverageType.hydrationCoefficient < 1 {
                    Text("≈ \(Int(entry.effectiveMl)) ml effective")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

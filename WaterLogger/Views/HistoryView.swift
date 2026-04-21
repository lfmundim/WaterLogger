import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    chartSection
                    if let date = viewModel.selectedDate {
                        dayDetailSection(date: date)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "History"))
            .onAppear {
                viewModel.load(context: modelContext)
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            Chart {
                ForEach(viewModel.daySummaries) { summary in
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("ml", summary.effectiveMl)
                    )
                    .foregroundStyle(
                        viewModel.selectedDate.map { Calendar.current.isDate($0, inSameDayAs: summary.date) } == true
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.5)
                    )
                    .cornerRadius(4)
                }

                // Goal line
                RuleMark(y: .value("Goal", viewModel.goalMl))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    .foregroundStyle(.red.opacity(0.7))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let ml = value.as(Double.self) { Text("\(Int(ml))") } }
                }
            }
            .frame(height: 220)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        viewModel.selectedDate = Calendar.current.startOfDay(for: date)
                                    }
                                }
                        )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Day detail

    private func dayDetailSection(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.headline)

            if viewModel.selectedDayEntries.isEmpty {
                Text("No entries for this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.selectedDayEntries) { entry in
                        HStack {
                            Image(systemName: entry.beverageType.systemImage)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.beverageType.displayName)
                                    .font(.subheadline)
                                Text(entry.date, style: .time)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(entry.amountMl)) ml")
                                .font(.subheadline).bold()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

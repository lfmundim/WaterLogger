import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("History")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .kerning(0.2)
                        Text(weekRangeLabel)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Button {
                            Task { await viewModel.stepWeek(by: -1, context: modelContext) }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .glassCard(cornerRadius: 99)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await viewModel.stepWeek(by: 1, context: modelContext) }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(viewModel.weekOffset == 0
                                    ? .white.opacity(0.2)
                                    : .white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .glassCard(cornerRadius: 99)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.weekOffset == 0)
                    }
                }
                .padding(.bottom, 10)

                // Bar chart
                chartCard
                    .padding(.bottom, 12)

                // Stat cards
                statsRow

                // Beverage breakdown
                breakdownCard
                    .padding(.top, 4)

                // Day detail (when a bar is tapped)
                if viewModel.selectedDate != nil {
                    dayDetailCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedDate)
        }
        .scrollIndicators(.hidden)
        .task { await viewModel.load(context: modelContext) }
    }

    // MARK: - Week range label

    private var weekRangeLabel: String {
        guard let first = viewModel.daySummaries.first?.date,
              let last  = viewModel.daySummaries.last?.date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let range = "\(fmt.string(from: first)) – \(fmt.string(from: last)), \(Calendar.current.component(.year, from: last))"
        return viewModel.weekOffset == 0 ? "This week · \(range)" : range
    }

    // MARK: - Bar chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("7-Day Overview")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.9)

            let maxV = max((viewModel.daySummaries.map(\.effectiveMl).max() ?? 0), viewModel.goalMl)
            let today = Calendar.current.startOfDay(for: .now)

            Chart {
                ForEach(viewModel.daySummaries) { summary in
                    let isToday = Calendar.current.isDate(summary.date, inSameDayAs: today)
                    let isSel   = viewModel.selectedDate.map {
                        Calendar.current.isDate($0, inSameDayAs: summary.date)
                    } ?? false

                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("ml", summary.effectiveMl)
                    )
                    .foregroundStyle(
                        isToday
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.iosBlueLight, Color.iosBlue],
                                startPoint: .top, endPoint: .bottom
                            ))
                            : isSel
                                ? AnyShapeStyle(Color.iosBlue.opacity(0.45))
                                : AnyShapeStyle(Color.iosBlue.opacity(0.24))
                    )
                    .cornerRadius(5)
                }

                RuleMark(y: .value("Goal", viewModel.goalMl))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(Color.iosBlue.opacity(0.3))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("GOAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.iosBlue.opacity(0.55))
                            .kerning(0.8)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let isToday = Calendar.current.isDate(date, inSameDayAs: today)
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? Color.iosBlue : Color.white.opacity(0.35))
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks { _ in } }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        let tapped = Calendar.current.startOfDay(for: date)
                                        withAnimation {
                                            viewModel.selectedDate = (viewModel.selectedDate == tapped) ? nil : tapped
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(height: 170)
            .padding(.bottom, 4)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Stat cards

    private var statsRow: some View {
        let sums = viewModel.daySummaries.map(\.effectiveMl)
        let avg  = sums.isEmpty ? 0 : sums.reduce(0, +) / Double(sums.count)
        let best = sums.max() ?? 0
        let hits = sums.filter { $0 >= viewModel.goalMl }.count

        let stats: [(label: String, value: String, accent: Bool)] = [
            ("7-Day Avg", String(format: "%.1fL", avg / 1000), false),
            ("Best Day",  String(format: "%.1fL", best / 1000), true),
            ("Goals Met", "\(hits) / 7", false),
        ]

        return HStack(spacing: 8) {
            ForEach(stats, id: \.label) { s in
                VStack(spacing: 4) {
                    Text(s.value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(s.accent ? Color.iosBlue : .white)
                        .kerning(-0.5)
                    Text(s.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.38))
                        .textCase(.uppercase)
                        .kerning(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .glassCard()
            }
        }
    }

    // MARK: - Beverage breakdown

    private var breakdownCard: some View {
        // Compute breakdown from all summaries
        var totals: [BeverageType: Double] = [:]
        for summary in viewModel.daySummaries {
            for entry in summary.entries {
                totals[entry.beverageType, default: 0] += entry.effectiveMl
            }
        }
        let grandTotal = totals.values.reduce(0, +)
        let sorted = totals
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 14) {
            Text("This Week")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.9)

            if sorted.isEmpty {
                Text("No data yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                ForEach(sorted, id: \.key) { bev, ml in
                    let pct = grandTotal > 0 ? ml / grandTotal : 0
                    HStack(spacing: 10) {
                        BevDotView(bevType: bev, size: 22, emojiMode: viewModel.emojiMode)
                        Text(String(localized: bev.displayName))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 64, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 99)
                                    .fill(Color.white.opacity(0.07))
                                RoundedRectangle(cornerRadius: 99)
                                    .fill(bev.accentColor)
                                    .frame(width: geo.size.width * pct)
                                    .animation(.easeOut(duration: 0.8), value: pct)
                            }
                        }
                        .frame(height: 4)

                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Day detail

    @ViewBuilder
    private var dayDetailCard: some View {
        if let date = viewModel.selectedDate {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(date, format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { withAnimation { viewModel.selectedDate = nil } } label: {
                        Text("×")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.selectedDayEntries.isEmpty {
                    Text("No entries for this day.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                } else {
                    ForEach(viewModel.selectedDayEntries) { entry in
                        HStack(spacing: 10) {
                            BevDotView(bevType: entry.beverageType, size: 30, emojiMode: viewModel.emojiMode)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(String(localized: entry.beverageType.displayName))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                Text(entry.date, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Text("\(Int(entry.amountMl)) ml")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(16)
            .glassCard()
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        HistoryView()
    }
    .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

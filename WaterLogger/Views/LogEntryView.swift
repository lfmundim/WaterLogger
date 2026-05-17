import SwiftUI
import SwiftData

struct LogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var viewModel: TodayViewModel

    @State private var selectedBeverage: BeverageType = .water
    @State private var selectedPresetMl: Double = 250
    @State private var customAmountText: String = ""
    @State private var useCustomAmount = false
    @FocusState private var customFieldFocused: Bool

    private var emojiMode: Bool { viewModel.settings.emojiMode }

    private var amountMl: Double {
        useCustomAmount ? (Double(customAmountText) ?? 0) : selectedPresetMl
    }

    private var effectiveMl: Int {
        Int(amountMl * selectedBeverage.hydrationCoefficient)
    }

    private var canLog: Bool { amountMl > 0 }

    // Quick-amount presets from settings (falls back to defaults)
    private var presets: [ContainerPreset] {
        viewModel.settings.containerPresets.isEmpty
            ? ContainerPreset.defaults
            : viewModel.settings.containerPresets
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Beverage picker
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Beverage")
                    beverageGrid
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 20)

                // Amount picker
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Amount")
                    presetRow
                    customInput
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                // Effective hydration note
                if selectedBeverage.hydrationCoefficient < 1 && canLog {
                    hydrationNote
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("Log Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(canLog ? "Log \(Int(amountMl)) ml" : "Log") {
                        guard canLog else { return }
                        let date = Date.now
                        Task {
                            await viewModel.logIntake(
                                date: date,
                                amountMl: amountMl,
                                beverageType: selectedBeverage,
                                context: modelContext
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canLog)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Beverage grid

    private var beverageGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(BeverageType.allCases, id: \.self) { bev in
                let sel = selectedBeverage == bev
                Button { selectedBeverage = bev } label: {
                    VStack(spacing: 7) {
                        BevDotView(bevType: bev, size: 30, emojiMode: emojiMode)
                        Text(String(localized: bev.displayName))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(sel ? bev.accentColor : Color.secondary)
                        Text("×\(bev.hydrationCoefficient, specifier: "%.2g")")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary.opacity(bev.hydrationCoefficient < 1 ? 1 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 6)
                    .background(
                        sel ? bev.accentColor.opacity(0.15) : Color.secondary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .shadow(color: sel ? bev.accentColor.opacity(0.1) : .clear, radius: 7)
                    .animation(.easeInOut(duration: 0.15), value: selectedBeverage)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Amount presets

    private var presetRow: some View {
        HStack(spacing: 7) {
            ForEach(presets.prefix(4), id: \.amountMl) { preset in
                let sel = !useCustomAmount && selectedPresetMl == preset.amountMl
                Button {
                    selectedPresetMl = preset.amountMl
                    useCustomAmount = false
                    customFieldFocused = false
                } label: {
                    Text("\(Int(preset.amountMl))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(sel ? Color.iosBlue : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            sel ? Color.iosBlue.opacity(0.15) : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .animation(.easeInOut(duration: 0.14), value: sel)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Custom input

    private var customInput: some View {
        HStack(spacing: 8) {
            Text("Custom:")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("e.g. 400", text: $customAmountText)
                .keyboardType(.numberPad)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.iosBlue)
                .focused($customFieldFocused)
                .onChange(of: customAmountText) { _, _ in useCustomAmount = true }
                .onSubmit { if customAmountText.isEmpty { useCustomAmount = false } }

            Text("ml")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            useCustomAmount ? Color.iosBlue.opacity(0.10) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - Effective hydration note

    private var hydrationNote: some View {
        HStack {
            Text("Effective hydration")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(effectiveMl) ml")
                .font(.system(size: 14, weight: .bold))
            + Text("  (\(Int(selectedBeverage.hydrationCoefficient * 100))%)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.9)
    }
}

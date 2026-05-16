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
        sheetPanel
    }

    // MARK: - Sheet panel

    private var sheetPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 99)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 16)

            // Title
            Text("Log Intake")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .kerning(-0.4)
                .padding(.horizontal, 18)
                .padding(.bottom, 20)

            // Beverage picker
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Beverage")
                beverageGrid
            }
            .padding(.horizontal, 18)
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

            // Log button
            logButton
                .padding(.horizontal, 18)
                .padding(.bottom, 48)
        }
        .background { sheetBackground }
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
                            .foregroundStyle(sel ? bev.accentColor : Color.white.opacity(0.52))
                        Text("×\(bev.hydrationCoefficient, specifier: "%.2g")")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(bev.hydrationCoefficient < 1 ? 0.28 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(sel ? bev.accentColor.opacity(0.12) : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        sel ? bev.accentColor.opacity(0.31) : Color.white.opacity(0.10),
                                        lineWidth: 0.5
                                    )
                            )
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
                        .foregroundStyle(sel ? Color.iosBlue : Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sel ? Color.iosBlue.opacity(0.22) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            sel ? Color.iosBlue.opacity(0.45) : Color.white.opacity(0.10),
                                            lineWidth: 0.5
                                        )
                                )
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
                .foregroundStyle(.white.opacity(0.38))

            TextField("e.g. 400", text: $customAmountText)
                .keyboardType(.numberPad)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.iosBlue)
                .focused($customFieldFocused)
                .onChange(of: customAmountText) { _, _ in useCustomAmount = true }
                .onSubmit { if customAmountText.isEmpty { useCustomAmount = false } }

            Text("ml")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(useCustomAmount ? Color.iosBlue.opacity(0.10) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            useCustomAmount ? Color.iosBlue.opacity(0.30) : Color.white.opacity(0.09),
                            lineWidth: 0.5
                        )
                )
        )
    }

    // MARK: - Effective hydration note

    private var hydrationNote: some View {
        HStack {
            Text("Effective hydration")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            Text("\(effectiveMl) ml")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
            + Text("  (\(Int(selectedBeverage.hydrationCoefficient * 100))%)")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Log button

    private var logButton: some View {
        Button {
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
        } label: {
            Text(canLog ? "Log \(Int(amountMl)) ml" : "Log Entry")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(canLog ? .white : .white.opacity(0.3))
                .kerning(-0.3)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    if canLog {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "5dbeff"), Color.iosBlueDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                                    .padding(1)
                            )
                            .shadow(color: Color.iosBlue.opacity(0.32), radius: 10, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                    }
                }
        }
        .disabled(!canLog)
        .animation(.easeInOut(duration: 0.18), value: canLog)
    }

    // MARK: - Sheet background

    private var sheetBackground: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(hex: "090e1c").opacity(0.97))
            // Top shine
            LinearGradient(
                colors: [.white.opacity(0.05), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            // Border
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.65), radius: 25, y: -10)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .kerning(0.9)
    }
}

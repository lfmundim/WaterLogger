import SwiftUI
import SwiftData

struct LogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var viewModel: TodayViewModel
    var settings: AppSettings

    @State private var selectedBeverage: BeverageType = .water
    @State private var selectedPresetMl: Double? = 250
    @State private var customAmountText: String = ""
    @State private var useCustomAmount = false

    private var amountMl: Double {
        if useCustomAmount {
            return Double(customAmountText) ?? 0
        }
        return selectedPresetMl ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Beverage")) {
                    beveragePicker
                }

                Section(String(localized: "Amount")) {
                    presetGrid
                    Toggle(String(localized: "Custom amount"), isOn: $useCustomAmount)
                    if useCustomAmount {
                        HStack {
                            TextField(String(localized: "ml"), text: $customAmountText)
                                .keyboardType(.numberPad)
                            Text("ml").foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(action: confirm) {
                        Label(String(localized: "Log intake"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(amountMl <= 0)
                }
            }
            .navigationTitle(String(localized: "Log Water"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var beveragePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BeverageType.allCases, id: \.self) { type in
                    VStack(spacing: 4) {
                        Image(systemName: type.systemImage)
                            .font(.title2)
                        Text(type.displayName)
                            .font(.caption2)
                    }
                    .padding(10)
                    .background(
                        selectedBeverage == type
                        ? Color.accentColor.opacity(0.2)
                        : Color(.secondarySystemGroupedBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedBeverage == type ? Color.accentColor : .clear, lineWidth: 2)
                    )
                    .onTapGesture { selectedBeverage = type }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var presetGrid: some View {
        let allPresets = settings.containerPresets.isEmpty
            ? ContainerPreset.defaults
            : settings.containerPresets

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
            ForEach(allPresets, id: \.amountMl) { preset in
                Button {
                    selectedPresetMl = preset.amountMl
                    useCustomAmount = false
                } label: {
                    VStack(spacing: 2) {
                        Text("\(Int(preset.amountMl))")
                            .font(.headline)
                        Text("ml").font(.caption2)
                        Text(preset.name).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedPresetMl == preset.amountMl && !useCustomAmount
                        ? Color.accentColor.opacity(0.2)
                        : Color(.secondarySystemGroupedBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                selectedPresetMl == preset.amountMl && !useCustomAmount
                                ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func confirm() {
        guard amountMl > 0 else { return }
        Task {
            await viewModel.logIntake(
                amountMl: amountMl,
                beverageType: selectedBeverage,
                context: modelContext
            )
            dismiss()
        }
    }
}

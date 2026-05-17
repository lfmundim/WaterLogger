import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showingAddPreset = false
    @State private var newPresetName = ""
    @State private var newPresetAmount = ""

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Daily Goal
                Section("Daily Goal") {
                    Stepper(
                        "\(Int(viewModel.dailyGoalMl)) ml",
                        value: $viewModel.dailyGoalMl,
                        in: 500...5000,
                        step: 250
                    )
                }

                // MARK: Reminder Window
                Section("Reminder Window") {
                    DatePicker("Wake Up", selection: $viewModel.windowStart, displayedComponents: .hourAndMinute)
                    DatePicker("Bedtime", selection: $viewModel.windowEnd, displayedComponents: .hourAndMinute)
                }

                // MARK: Quick-Add Presets
                Section("Quick-Add Presets") {
                    ForEach(viewModel.containerPresets) { preset in
                        LabeledContent(preset.name) {
                            Text("\(Int(preset.amountMl)) ml")
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                    .onMove { viewModel.movePresets(from: $0, to: $1) }
                    .onDelete { viewModel.deletePresets(at: $0) }

                    Button {
                        showingAddPreset = true
                    } label: {
                        Label("Add Preset", systemImage: "plus.circle.fill")
                    }
                }

                // MARK: Display
                Section("Display") {
                    Toggle("Emoji Labels", isOn: $viewModel.emojiMode)
                }

                // MARK: Integrations
                Section("Integrations") {
                    LabeledContent("HealthKit Sync") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "34d399"))
                    }
                    LabeledContent("Notifications") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "34d399"))
                    }
                }

                // MARK: Version footer
                Section {
                    LabeledContent("WaterLogger") {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                EditButton()
            }
            .onAppear { viewModel.load(context: modelContext) }
            .onChange(of: viewModel.dailyGoalMl)     { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.windowStart)      { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.windowEnd)        { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.containerPresets) { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.emojiMode)        { _, _ in viewModel.save(context: modelContext) }
            .sheet(isPresented: $showingAddPreset) { addPresetSheet }
        }
    }

    // MARK: - Add preset sheet

    private var addPresetSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name"), text: $newPresetName)
                    HStack {
                        TextField(String(localized: "Amount"), text: $newPresetAmount)
                            .keyboardType(.numberPad)
                        Text("ml").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "New Preset"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        newPresetName = ""; newPresetAmount = ""; showingAddPreset = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        if let amount = Double(newPresetAmount), !newPresetName.isEmpty {
                            viewModel.addPreset(name: newPresetName, amountMl: amount)
                        }
                        newPresetName = ""; newPresetAmount = ""; showingAddPreset = false
                    }
                    .disabled(newPresetName.isEmpty || Double(newPresetAmount) == nil)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

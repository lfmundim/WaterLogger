import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var newPresetName: String = ""
    @State private var newPresetAmount: String = ""
    @State private var showingAddPreset = false

    var body: some View {
        NavigationStack {
            Form {
                goalSection
                windowSection
                presetsSection
            }
            .navigationTitle(String(localized: "Settings"))
            .onAppear { viewModel.load(context: modelContext) }
            .onChange(of: viewModel.dailyGoalMl) { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.windowStart)  { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.windowEnd)    { _, _ in viewModel.save(context: modelContext) }
            .onChange(of: viewModel.containerPresets) { _, _ in viewModel.save(context: modelContext) }
            .sheet(isPresented: $showingAddPreset) { addPresetSheet }
        }
    }

    // MARK: - Sections

    private var goalSection: some View {
        Section(String(localized: "Daily Goal")) {
            HStack {
                Text("Goal")
                Spacer()
                Stepper(
                    "\(Int(viewModel.dailyGoalMl)) ml",
                    value: $viewModel.dailyGoalMl,
                    in: 500...5000,
                    step: 100
                )
            }
        }
    }

    private var windowSection: some View {
        Section(String(localized: "Reminder Window")) {
            DatePicker(
                String(localized: "Start"),
                selection: $viewModel.windowStart,
                displayedComponents: .hourAndMinute
            )
            DatePicker(
                String(localized: "End"),
                selection: $viewModel.windowEnd,
                displayedComponents: .hourAndMinute
            )
        }
    }

    private var presetsSection: some View {
        Section(String(localized: "Container Presets")) {
            ForEach(viewModel.containerPresets, id: \.amountMl) { preset in
                HStack {
                    Text(preset.name)
                    Spacer()
                    Text("\(Int(preset.amountMl)) ml").foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                viewModel.deletePresets(at: offsets)
            }

            Button {
                showingAddPreset = true
            } label: {
                Label(String(localized: "Add Preset"), systemImage: "plus")
            }
        }
    }

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
                    Button(String(localized: "Cancel")) { showingAddPreset = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        if let amount = Double(newPresetAmount), !newPresetName.isEmpty {
                            viewModel.addPreset(name: newPresetName, amountMl: amount)
                        }
                        newPresetName = ""
                        newPresetAmount = ""
                        showingAddPreset = false
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

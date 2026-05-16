import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showingAddPreset = false
    @State private var newPresetName = ""
    @State private var newPresetAmount = ""
    @State private var presetIndexToDelete: Int?
    @State private var draggingPresetID: UUID?
    @State private var dragStartIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(0.2)
                    .padding(.bottom, 2)

                goalSection
                reminderSection
                presetsSection
                displaySection
                integrationsSection
                versionFooter
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear { viewModel.load(context: modelContext) }
        .alert(
            "Delete Preset?",
            isPresented: Binding(
                get: { presetIndexToDelete != nil },
                set: { if !$0 { presetIndexToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let idx = presetIndexToDelete {
                    viewModel.deletePresets(at: IndexSet(integer: idx))
                }
                presetIndexToDelete = nil
            }
            Button("Cancel", role: .cancel) { presetIndexToDelete = nil }
        } message: {
            if let idx = presetIndexToDelete, idx < viewModel.containerPresets.count {
                let preset = viewModel.containerPresets[idx]
                Text("\(preset.name) · \(Int(preset.amountMl)) ml")
            }
        }
        .onChange(of: viewModel.dailyGoalMl)     { _, _ in viewModel.save(context: modelContext) }
        .onChange(of: viewModel.windowStart)      { _, _ in viewModel.save(context: modelContext) }
        .onChange(of: viewModel.windowEnd)        { _, _ in viewModel.save(context: modelContext) }
        .onChange(of: viewModel.containerPresets) { _, _ in viewModel.save(context: modelContext) }
        .onChange(of: viewModel.emojiMode)        { _, _ in viewModel.save(context: modelContext) }
        .sheet(isPresented: $showingAddPreset) { addPresetSheet }
    }

    // MARK: - Sections

    private var goalSection: some View {
        settingsSection(title: "Daily Goal") {
            settingsRow(label: "Daily Target", isLast: true) {
                HStack(spacing: 12) {
                    stepperButton(icon: "−") {
                        viewModel.dailyGoalMl = max(500, viewModel.dailyGoalMl - 250)
                    }
                    Text("\(Int(viewModel.dailyGoalMl)) ml")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.iosBlue)
                        .frame(minWidth: 76)
                        .multilineTextAlignment(.center)
                    stepperButton(icon: "+", accent: true) {
                        viewModel.dailyGoalMl = min(5000, viewModel.dailyGoalMl + 250)
                    }
                }
            }
        }
    }

    private let presetRowHeight: CGFloat = 50

    private func presetRow(preset: ContainerPreset, idx: Int) -> some View {
        let isDragging = draggingPresetID == preset.id
        return HStack {
            // Drag handle — gesture lives here so scroll is unaffected
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isDragging ? Color.iosBlue.opacity(0.8) : .white.opacity(0.30))
                .frame(width: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .global)
                        .onChanged { value in
                            if draggingPresetID == nil {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    draggingPresetID = preset.id
                                }
                                dragStartIndex = idx
                            }
                            guard draggingPresetID == preset.id else { return }

                            let target = max(0, min(viewModel.containerPresets.count - 1,
                                                    dragStartIndex + Int((value.translation.height / presetRowHeight).rounded())))
                            guard let cur = viewModel.containerPresets.firstIndex(where: { $0.id == preset.id }),
                                  target != cur else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.movePresets(from: IndexSet(integer: cur),
                                                     to: target > cur ? target + 1 : target)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.18)) { draggingPresetID = nil }
                            viewModel.save(context: modelContext)
                        }
                )

            Text(preset.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 8) {
                Text("\(Int(preset.amountMl)) ml")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.48))
                Button { presetIndexToDelete = idx } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color.red.opacity(0.7))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(isDragging ? Color.iosBlue.opacity(0.07) : Color.clear)
        .scaleEffect(isDragging ? 1.015 : 1)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .overlay(alignment: .bottom) {
            if idx < viewModel.containerPresets.count - 1 {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
    }

    private var reminderSection: some View {
        settingsSection(title: "Reminder Window") {
            settingsRow(label: "Wake Up") {
                DatePicker("", selection: $viewModel.windowStart, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            settingsRow(label: "Bedtime", isLast: true) {
                DatePicker("", selection: $viewModel.windowEnd, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
        }
    }

    private var presetsSection: some View {
        settingsSection(title: "Quick-Add Presets") {
            ForEach(viewModel.containerPresets) { preset in
                let idx = viewModel.containerPresets.firstIndex(where: { $0.id == preset.id }) ?? 0
                presetRow(preset: preset, idx: idx)
            }
            // Add preset row
            Button { showingAddPreset = true } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.iosBlue)
                        .font(.system(size: 16))
                    Text("Add Preset")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.iosBlue)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
    }

    private var displaySection: some View {
        settingsSection(title: "Display") {
            settingsRow(label: "Emoji Labels", isLast: true) {
                Toggle("", isOn: $viewModel.emojiMode)
                    .labelsHidden()
                    .tint(Color.iosBlue)
            }
        }
    }

    private var integrationsSection: some View {
        settingsSection(title: "Integrations") {
            settingsRow(label: "HealthKit Sync") {
                // HealthKit toggle is informational — auth is requested lazily on log
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "34d399"))
                    .font(.system(size: 18))
            }
            settingsRow(label: "Notifications", isLast: true) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "34d399"))
                    .font(.system(size: 18))
            }
        }
    }

    private var versionFooter: some View {
        HStack {
            Text("WaterLogger")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(appVersion)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard()
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(v)"
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

    // MARK: - Reusable components

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.9)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .glassCard(cornerRadius: 20)
        }
    }

    private func settingsRow<Trailing: View>(
        label: String,
        isLast: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
    }

    private func stepperButton(icon: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 18))
                .foregroundStyle(accent ? Color.iosBlue : .white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(accent ? Color.iosBlue.opacity(0.18) : Color.white.opacity(0.09))
                        .overlay(
                            Circle().strokeBorder(
                                accent ? Color.iosBlue.opacity(0.4) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppBackground()
        SettingsView()
    }
    .modelContainer(for: [IntakeEntry.self, AppSettings.self], inMemory: true)
}

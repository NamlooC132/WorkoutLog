import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

/// Units, defaults for new exercises, and JSON backup / import.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRestSeconds = AppSettings.fallbackRestSeconds
    @AppStorage(SettingsKey.defaultWeightIncrement) private var defaultIncrement = AppSettings.fallbackIncrement

    @State private var vm = SettingsViewModel()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var incrementOptions: [Double] {
        Array(Set(ExerciseEditorViewModel.baseIncrements + [defaultIncrement])).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weight unit", selection: $unit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Units")
                } footer: {
                    Text("Weights are stored precisely, so switching units only changes how they're shown. Progressive overload adds exactly \(Fmt.number(unit.progressionStep)) \(unit.symbol).")
                }

                Section {
                    Stepper(value: $defaultRestSeconds, in: RestTime.range, step: RestTime.step) {
                        LabeledContent("Default rest", value: Fmt.rest(defaultRestSeconds))
                    }
                    Picker("Default weight step", selection: $defaultIncrement) {
                        ForEach(incrementOptions, id: \.self) { value in
                            Text("\(Fmt.number(value)) \(unit.symbol)").tag(value)
                        }
                    }
                } header: {
                    Text("Defaults for new exercises")
                }

                Section {
                    Button {
                        vm.export(includeHistory: true, context: context)
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        vm.export(includeHistory: false, context: context)
                    } label: {
                        Label("Share Routines Only", systemImage: "person.2")
                    }
                    Button {
                        vm.isImporting = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup & sharing")
                } footer: {
                    Text("“Export All Data” makes a JSON file with routines, exercises, photos and history – use it to move to a new phone. “Share Routines Only” leaves out your history, for sending routines to friends. Importing merges into what's here and never deletes anything.")
                }

                Section("Rest timer alerts") {
                    LabeledContent("Notifications", value: notificationText)
                    if notificationStatus == .denied {
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Button("Add Sample Routines") { vm.addSampleRoutines(context: context) }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: unit) { _, newUnit in
                // Swap the default step to a sensible one for the new unit.
                if newUnit == .lbs, defaultIncrement == 2.5 { defaultIncrement = 5 }
                if newUnit == .kg, defaultIncrement == 5 { defaultIncrement = 2.5 }
            }
            .sheet(item: $vm.shareFile) { file in
                ActivityView(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $vm.isImporting, allowedContentTypes: [.json]) { result in
                vm.handleImport(result, context: context)
            }
            .alert(vm.alertTitle, isPresented: alertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.alertMessage ?? "")
            }
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshNotificationStatus() } }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { vm.alertMessage != nil }, set: { if !$0 { vm.alertMessage = nil } })
    }

    private var notificationText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "On"
        case .denied: "Off"
        default: "Asked on first workout"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await NotificationService.shared.authorizationStatus()
    }
}

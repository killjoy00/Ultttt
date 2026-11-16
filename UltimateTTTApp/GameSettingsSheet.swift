import SwiftUI

struct GameSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(PlaySettings.soundKey) private var soundEnabled = true
    @AppStorage(PlaySettings.hapticsKey) private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("Follow iPhone").tag(AppearancePreference.system.rawValue)
                        Text("Light").tag(AppearancePreference.light.rawValue)
                        Text("Dark").tag(AppearancePreference.dark.rawValue)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Follow iPhone changes automatically with your device's appearance.")
                }

                Section {
                    Toggle("Sound effects", isOn: $soundEnabled)
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                } header: {
                    Text("Sound & feel")
                } footer: {
                    Text("Short game sounds respect your iPhone's silent mode. Haptics use the device's built-in vibration.")
                }

                Section {
                    Label("Game Center sends turn notifications when your opponent moves.", systemImage: "bell")
                        .font(.subheadline)
                } header: {
                    Text("Online turns")
                } footer: {
                    Text("To change delivery, open iPhone Settings → Notifications and check Game Center. Notification delivery depends on your Apple Account and device settings.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

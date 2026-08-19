import SwiftUI

@MainActor
struct SettingsView: View {
    let store: RemindersStore
    @State private var launchAtLogin: LaunchAtLoginStore

    @Environment(\.scenePhase) private var scenePhase

    init(store: RemindersStore) {
        self.store = store
        _launchAtLogin = State(initialValue: LaunchAtLoginStore())
    }

    init(store: RemindersStore, launchAtLogin: LaunchAtLoginStore) {
        self.store = store
        _launchAtLogin = State(initialValue: launchAtLogin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black)
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.notchAccent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("NotchDo")
                        .font(.headline)
                    Text("A calm home for Reminders in your notch.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                    .disabled(launchAtLogin.state == .unavailable)

                Text(launchAtLogin.state.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if launchAtLogin.state == .requiresApproval {
                    Button("Open Login Items Settings") {
                        launchAtLogin.openSystemSettings()
                    }
                    .accessibilityHint("Opens System Settings to approve NotchDo")
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Launch at Login error: \(errorMessage)")
                }
            }

            Divider()

            LabeledContent("Reminders access") {
                Text(accessText)
                    .foregroundStyle(store.authorization == .fullAccess ? .green : .secondary)
            }

            Text("NotchDo stores no task database. Changes are saved directly to Apple Reminders.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(versionText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            launchAtLogin.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                launchAtLogin.refresh()
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isRequested },
            set: { launchAtLogin.setRequested($0) }
        )
    }

    private var accessText: String {
        switch store.authorization {
        case .fullAccess: return "Connected"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .requesting: return "Requesting…"
        case .notDetermined: return "Not requested"
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        default:
            return "NotchDo"
        }
    }
}

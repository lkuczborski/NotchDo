import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: RemindersStore

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

            LabeledContent("Reminders access") {
                Text(accessText)
                    .foregroundStyle(store.authorization == .fullAccess ? .green : .secondary)
            }

            Text("NotchDo stores no task database. Changes are saved directly to Apple Reminders.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 420)
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
}

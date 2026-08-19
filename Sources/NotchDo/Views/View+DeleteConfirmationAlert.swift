import EventKit
import SwiftUI

extension View {
    func deleteConfirmationAlert(
        isPresented: Binding<Bool>,
        reminder: EKReminder?,
        onDelete: @escaping (EKReminder) -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        alert(
            "Delete Repeating Reminder?",
            isPresented: isPresented,
            presenting: reminder
        ) { reminder in
            Button("Delete", role: .destructive) {
                onDelete(reminder)
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.defaultAction)
        } message: { _ in
            Text(
                "This reminder has a repeat schedule. Deleting it removes "
                    + "the reminder and its repeat schedule."
            )
        }
    }
}

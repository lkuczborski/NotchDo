import SwiftUI

struct CenteredDateField: View {
    @Binding var selection: Date
    let onPresentationChange: (Bool) -> Void
    let onQuickSchedule: (ReminderQuickSchedule) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text(formattedValue)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .frame(width: 72, height: 22)
                .background(
                    .white.opacity(0.075),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.13), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Due date")
        .accessibilityValue(formattedValue)
        .accessibilityHint("Opens a calendar")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            datePickerPopover
        }
        .onChange(of: isPresented) { _, presented in
            onPresentationChange(presented)
        }
        .onDisappear {
            if isPresented {
                onPresentationChange(false)
            }
        }
    }

    private var datePickerPopover: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Schedule")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    quickScheduleButton(.today)
                    quickScheduleButton(.tomorrow)
                }

                HStack(spacing: 6) {
                    quickScheduleButton(.nextWeek)
                    quickScheduleButton(.clearDate)
                }
            }
            .frame(width: 152)

            FocuslessGraphicalDatePicker(selection: $selection)
                .frame(width: 152, height: 154)

            HStack {
                Spacer(minLength: 0)
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .frame(width: 172)
        .preferredColorScheme(.dark)
    }

    private func quickScheduleButton(_ schedule: ReminderQuickSchedule) -> some View {
        Button(schedule.title) {
            onQuickSchedule(schedule)
            isPresented = false
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity)
        .accessibilityHint("Sets or clears the reminder due date")
    }

    private var formattedValue: String {
        selection.formatted(date: .numeric, time: .omitted)
    }
}

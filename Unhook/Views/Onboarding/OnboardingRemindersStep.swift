import SwiftUI

/// Explains the daily pledge reminder and milestone alerts before iOS asks for notification permission,
/// so the system prompt arrives with context instead of out of nowhere.
struct OnboardingRemindersStep: View {
    let onDone: () -> Void

    @State private var isRequesting = false

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    var body: some View {
        OnboardingStepLayout(
            title: Text("Stay on track"),
            subtitle: Text("Gentle nudges at the moments that matter. Change them anytime in Settings.")
        ) {
            VStack(spacing: 12) {
                bell
                featureRow(
                    systemImage: "hand.raised.fill",
                    tint: Palette.amber,
                    title: Text("Daily pledge"),
                    detail: Text("A reminder at \(reminderTime) to commit to one clean day. Just today.")
                )
                featureRow(
                    systemImage: "trophy.fill",
                    tint: Palette.sun,
                    title: Text("Milestone alerts"),
                    detail: Text("Know the moment you hit 1 hour, 1 day, 1 week and beyond.")
                )
                featureRow(
                    systemImage: "lock.fill",
                    tint: Palette.mint,
                    title: Text("Private and quiet"),
                    detail: Text("No marketing, ever. Reminders are created right on your device.")
                )
            }
        } footer: {
            Button {
                Task { await enableReminders() }
            } label: {
                ZStack {
                    Text("Turn on reminders")
                        .opacity(isRequesting ? 0 : 1)
                    if isRequesting {
                        ProgressView()
                            .tint(Palette.inkText)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isRequesting)

            Button {
                Haptics.tap()
                onDone()
            } label: {
                Text("Maybe later")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
        }
    }

    private var bell: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(Palette.inkText)
            .frame(width: 92, height: 92)
            .background(Brand.gradient, in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: Palette.amber.opacity(0.5), radius: 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityHidden(true)
    }

    private func featureRow(systemImage: String, tint: Color, title: Text, detail: Text) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: systemImage, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                detail
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private var reminderTime: String {
        let date = Calendar.current.date(
            bySettingHour: AppSettings.reminderHour,
            minute: AppSettings.reminderMinute,
            second: 0,
            of: .now
        ) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func enableReminders() async {
        guard !isRequesting else { return }
        isRequesting = true
        Haptics.tap()
        if await NotificationManager.requestAuthorization() {
            UserDefaults.standard.set(true, forKey: AppSettings.Keys.reminderEnabled)
            NotificationManager.scheduleDailyReminder(hour: AppSettings.reminderHour, minute: AppSettings.reminderMinute)
        }
        isRequesting = false
        onDone()
    }
}

#Preview {
    ZStack {
        DawnBackground(glow: 0.6)
        OnboardingRemindersStep {}
    }
    .environment(\.colorScheme, .dark)
    .previewEnvironment()
}

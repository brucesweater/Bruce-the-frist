import SwiftUI

/// A compact glass card for the Today and habit screens that opens the private craving coach in a sheet.
/// The root view is a single Button, so an accessibility identifier set by the caller lands on it.
struct CoachEntryCard: View {
    /// The habit to talk about, or nil to let the coach pick the habit with the longest streak.
    let habit: Habit?

    @State private var isShowingCoach = false
    @State private var hasOnDeviceAI = false

    private var subtitle: String {
        hasOnDeviceAI
            ? String(localized: "Private on-device AI that talks you through any craving.")
            : String(localized: "A private chat that talks you through any craving.")
    }

    var body: some View {
        Button {
            Haptics.tap()
            isShowingCoach = true
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: "sparkles", tint: Palette.violet, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Talk to your coach")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassSurface(cornerRadius: 24)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a private chat with your coach")
        .onAppear {
            hasOnDeviceAI = CoachProvider.isOnDeviceAIAvailable
        }
        .sheet(isPresented: $isShowingCoach) {
            CoachView(habit: habit)
        }
    }
}

#Preview {
    CoachEntryCard(habit: nil)
        .padding()
        .frame(maxHeight: .infinity)
        .background { DawnBackground() }
        .previewEnvironment()
}

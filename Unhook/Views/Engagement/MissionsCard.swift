import SwiftUI
import SwiftData

/// Today's three missions. Self-reported ones check off with a tap (and can be unchecked the same day); the pledge
/// and SOS missions complete on their own.
struct MissionsCard: View {
    @Query private var completions: [MissionCompletion]
    @Query private var pledges: [Pledge]
    @Query private var urges: [Urge]
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {}

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            content(for: timeline.date)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("missionsCard")
    }

    private func content(for now: Date) -> some View {
        let statuses = missionStatuses(on: now)
        let doneCount = statuses.filter(\.isDone).count
        let isPerfect = !statuses.isEmpty && doneCount == statuses.count
        return VStack(alignment: .leading, spacing: 6) {
            header(doneCount: doneCount, total: statuses.count)
            VStack(spacing: 0) {
                ForEach(statuses) { status in
                    MissionRow(
                        status: status,
                        onToggle: { toggle(status.mission) },
                        onSOS: openSOS
                    )
                    if status.id != statuses.last?.id {
                        Divider()
                            .overlay(Palette.hairline)
                            .padding(.leading, 40)
                    }
                }
            }
            if isPerfect {
                perfectBanner
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24, tint: isPerfect ? Palette.sun : nil, highlighted: isPerfect)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: doneCount)
    }

    private func missionStatuses(on now: Date) -> [MissionStatus] {
        let calendar = Calendar.current
        let beatCraving = urges.contains { $0.resisted && calendar.isDate($0.date, inSameDayAs: now) }
        return DailyMissions.missions(for: now, calendar: calendar).map { mission in
            let isDone = DailyMissions.isCompleted(
                mission,
                on: now,
                completions: completions,
                pledges: pledges,
                urges: urges,
                calendar: calendar
            )
            let isAutomatic: Bool
            switch mission.kind {
            case .selfReported: isAutomatic = false
            case .pledge: isAutomatic = true
            case .sos: isAutomatic = beatCraving
            }
            return MissionStatus(mission: mission, isDone: isDone, isAutomatic: isAutomatic)
        }
    }

    private func header(doneCount: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            IconBadge(systemImage: "target", tint: Palette.amber, size: 28)
            Text("Today's missions")
                .font(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            Text("\(doneCount)/\(total)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(doneCount == total ? Palette.sun : Palette.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today's missions, \(doneCount) of \(total) done"))
        .accessibilityAddTraits(.isHeader)
    }

    private var perfectBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .accessibilityHidden(true)
            Text("Perfect day! +\(XPRewards.perPerfectDay) XP")
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(Palette.inkText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Brand.gradient, in: Capsule())
        .shadow(color: Palette.amber.opacity(0.45), radius: 12, y: 4)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    /// Checks a mission off for today, or unchecks it if it was checked by hand.
    private func toggle(_ mission: Mission) {
        let calendar = Calendar.current
        let now = Date.now
        let existing = completions.filter { $0.missionID == mission.id && calendar.isDate($0.day, inSameDayAs: now) }
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)) {
            if existing.isEmpty {
                context.insert(MissionCompletion(day: calendar.startOfDay(for: now), missionID: mission.id, completedAt: now))
            } else {
                existing.forEach { context.delete($0) }
            }
        }
        if existing.isEmpty {
            Haptics.success()
        } else {
            Haptics.selection()
        }
    }

    private func openSOS() {
        Haptics.tap()
        router.isShowingSOS = true
    }
}

private struct MissionStatus: Identifiable {
    let mission: Mission
    let isDone: Bool
    /// True when the mission completed itself (pledge taken, craving beaten), so it can't be unchecked here.
    let isAutomatic: Bool

    var id: String { mission.id }
}

private struct MissionRow: View {
    let status: MissionStatus
    let onToggle: () -> Void
    let onSOS: () -> Void

    private var mission: Mission { status.mission }
    private var isDone: Bool { status.isDone }

    var body: some View {
        switch mission.kind {
        case .selfReported:
            toggleRow
        case .pledge:
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? Text("Done") : Text("Not done yet"))
        case .sos:
            HStack(spacing: 10) {
                if status.isAutomatic {
                    rowContent
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(Text("Done"))
                } else {
                    toggleRow
                }
                if !isDone {
                    sosButton
                }
            }
        }
    }

    private var toggleRow: some View {
        Button(action: onToggle) {
            rowContent
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? Text("Done") : Text("Not done"))
        .accessibilityHint(isDone ? Text("Double-tap to uncheck") : Text("Double-tap to check off"))
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            EngagementCheckmark(isDone: isDone)
            VStack(alignment: .leading, spacing: 2) {
                Text(mission.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? Palette.textSecondary : Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Chip(text: Text("+\(XPRewards.perMission) XP"), tint: Palette.amber, filled: isDone)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var detail: String {
        switch mission.kind {
        case .selfReported:
            return mission.detail
        case .pledge:
            return isDone
                ? String(localized: "Pledge taken. Nice work.")
                : String(localized: "Done automatically when you take your pledge")
        case .sos:
            if isDone {
                return status.isAutomatic
                    ? String(localized: "You beat a craving today. That's huge.")
                    : String(localized: "Checked off. Staying free counts.")
            }
            return String(localized: "Ride out a craving with SOS. No craving today? Tap to check it off.")
        }
    }

    private var sosButton: some View {
        Button(action: onSOS) {
            EngagementCapsuleLabel(text: Text("SOS"), gradient: Brand.sos, foreground: .white, font: .caption.weight(.bold))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(Text("Open SOS"))
    }
}

#Preview {
    ScrollView {
        MissionsCard()
            .padding()
    }
    .dawnScreenBackground()
    .previewEnvironment()
}

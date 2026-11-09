import StoreKit
import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @Query private var habits: [Habit]
    @Query private var pledges: [Pledge]
    @Query private var urges: [Urge]
    @Query private var relapses: [Relapse]
    @Query private var savingsGoals: [SavingsGoal]

    @AppStorage(AppSettings.Keys.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(AppSettings.Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppSettings.Keys.reminderEnabled) private var reminderEnabled = false
    @AppStorage(AppSettings.Keys.reminderHour) private var reminderHour = AppSettings.defaultReminderHour
    @AppStorage(AppSettings.Keys.reminderMinute) private var reminderMinute = AppSettings.defaultReminderMinute
    @AppStorage(AppSettings.Keys.milestoneAlertsEnabled) private var milestoneAlertsEnabled = true
    @AppStorage(AppSettings.Keys.dataResetCount) private var dataResetCount = 0
    @AppStorage(AppLockSettings.enabledKey) private var appLockEnabled = false

    @State private var confirmingErase = false
    @State private var notificationsDenied = false
    @State private var isRestoring = false
    @State private var showingManageSubscriptions = false
    @State private var showingPrivacyPolicy = false
    @State private var isEnablingAppLock = false
    /// Filled in on appear; asking LocalAuthentication on every init of this view would be wasted work.
    @State private var appLockMethod: AppLockMethod = .faceID
    @State private var canUseAppLock = true
    @State private var exportFiles: DataExportFiles?
    @State private var alert: SettingsAlert?
    /// True once the big "Settings" title has scrolled away, so the small one in the navigation bar takes over.
    @State private var showsInlineTitle = false
    @ScaledMetric(relativeTo: .title3) private var upgradeIconSize: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var founderPhotoSize: CGFloat = 52

    /// A one-button alert: restore results, export and lock errors.
    private struct SettingsAlert {
        let title: String
        let message: String
    }

    private static let currencies = [
        "USD", "EUR", "GBP", "CNY", "JPY", "KRW", "INR", "CAD", "AUD", "NZD",
        "CHF", "SEK", "NOK", "SGD", "HKD", "BRL", "MXN", "ZAR", "AED", "TRY",
    ]

    /// Kept outside the store by the rank and achievement features, and erased with everything else.
    private static let engagementDefaultsKeys = ["lastSeenRankLevel", "achievementTracker.unlocked"]

    var body: some View {
        NavigationStack {
            styledForm
                .confirmationDialog("Erase everything?", isPresented: $confirmingErase, titleVisibility: .visible) {
                    Button("Erase all data", role: .destructive, action: eraseAll)
                } message: {
                    Text("All habits, streaks, pledges, savings goals, challenge progress and history will be permanently deleted.")
                }
                .alert(alert?.title ?? "", isPresented: isShowingAlert, presenting: alert) { _ in
                    Button("OK", role: .cancel) {}
                } message: { alert in
                    Text(alert.message)
                }
                .sheet(item: $exportFiles) { files in
                    DataExportSheet(files: files)
                }
                .sheet(isPresented: $showingPrivacyPolicy) {
                    PrivacyPolicySheet()
                }
                .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
                .onAppear {
                    refreshAppLockAvailability()
                }
                .onChange(of: scenePhase) { _, phase in
                    // The user may have set up Face ID, a passcode or notifications in the Settings app meanwhile.
                    if phase == .active {
                        refreshAppLockAvailability()
                        Task { await refreshNotificationStatus() }
                    }
                }
        }
    }

    private var styledForm: some View {
        form
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    inlineTitle
                }
            }
            .fadesContentUnderNavigationBar()
            .task {
                await refreshNotificationStatus()
            }
            .onChange(of: reminderEnabled) { _, enabled in
                Task { await updateReminder(enabled: enabled) }
            }
            .onChange(of: milestoneAlertsEnabled) { _, enabled in
                Task { await updateMilestoneAlerts(enabled: enabled) }
            }
    }

    private var form: some View {
        Form {
            titleSection
            founderSection
            if Monetization.isProEnabled {
                proSection
            }
            remindersSection
            preferencesSection
            appIconSection
            supportSection
            privacySection
            dataSection
            aboutSection
        }
        .tint(Palette.amber)
        .dawnScreenBackground()
    }

    // MARK: Header

    private var titleSection: some View {
        Section {
            Text("Settings")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .onAppear { showsInlineTitle = false }
                .onDisappear { showsInlineTitle = true }
        }
        .listSectionSpacing(.compact)
    }

    private var inlineTitle: some View {
        Text("Settings")
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(Palette.textPrimary)
            .opacity(showsInlineTitle ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showsInlineTitle)
            .accessibilityHidden(!showsInlineTitle)
    }

    private var founderSection: some View {
        Section {
            NavigationLink {
                FounderView()
            } label: {
                founderCard
            }
            .accessibilityIdentifier("founderRow")
            .listRowBackground(founderRowBackground)
        }
    }

    private var founderCard: some View {
        HStack(spacing: 14) {
            FounderAvatar(size: founderPhotoSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Made by Bruce Gao")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text("Meet the founder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.sun)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var founderRowBackground: some View {
        ZStack {
            Palette.surface.opacity(0.72)
            LinearGradient(
                colors: [Palette.amber.opacity(0.2), Palette.rose.opacity(0.1), Palette.violet.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Sections

    private var proSection: some View {
        Section {
            if store.isPro {
                proActiveRow
                if hasActiveSubscription {
                    Button {
                        showingManageSubscriptions = true
                    } label: {
                        SettingsRowLabel(title: "Manage subscription", systemImage: "creditcard.fill", tint: Palette.sky)
                    }
                }
            } else {
                upgradeRow
                restoreButton
            }
        } header: {
            SettingsSectionHeader(title: "Unhook Pro", systemImage: "crown.fill", tint: Palette.amber)
        }
        .settingsGlassRows()
    }

    private var remindersSection: some View {
        Section {
            Toggle(isOn: $reminderEnabled) {
                SettingsRowLabel(title: "Daily pledge reminder", systemImage: "bell.badge.fill", tint: Palette.amber)
            }
            if reminderEnabled {
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    SettingsRowLabel(title: "Time", systemImage: "clock.fill", tint: Palette.time)
                }
            }
            Toggle(isOn: $milestoneAlertsEnabled) {
                SettingsRowLabel(title: "Milestone alerts", systemImage: "trophy.fill", tint: Palette.celebrate)
            }
        } header: {
            SettingsSectionHeader(title: "Reminders", systemImage: "bell.fill", tint: Palette.amber)
        } footer: {
            if notificationsDenied {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications are off for Unhook, so reminders and milestone alerts can't arrive.")
                        .foregroundStyle(Palette.textSecondary)
                    Button("Turn on notifications") {
                        Task { await turnOnNotifications() }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.amber)
                }
                .font(.footnote)
            }
        }
        .settingsGlassRows()
    }

    private var preferencesSection: some View {
        Section {
            Picker(selection: $currencyCode) {
                ForEach(currencyOptions, id: \.self) { code in
                    Text(currencyLabel(code)).tag(code)
                }
            } label: {
                SettingsRowLabel(title: "Currency", systemImage: "banknote.fill", tint: Palette.money)
            }
            Toggle(isOn: $hapticsEnabled) {
                SettingsRowLabel(title: "Haptics", systemImage: "iphone.radiowaves.left.and.right", tint: Palette.violet)
            }
        } header: {
            SettingsSectionHeader(title: "Preferences", systemImage: "slider.horizontal.3", tint: Palette.sky)
        }
        .settingsGlassRows()
    }

    private var appIconSection: some View {
        Section {
            AppIconPicker()
        } header: {
            SettingsSectionHeader(title: "App icon", systemImage: "app.badge.fill", tint: Palette.violet)
        } footer: {
            footerText(Text("Pick how Unhook looks on your Home Screen."))
        }
        .settingsGlassRows()
    }

    private var supportSection: some View {
        Section {
            Link(destination: FounderLinks.supportEmail) {
                SettingsRowLabel(title: "Contact support", systemImage: "envelope.fill", tint: Palette.sky, accessory: .external)
            }
            Link(destination: FounderLinks.supportPage) {
                SettingsRowLabel(title: "Support website", systemImage: "questionmark.circle.fill", tint: Palette.violet, accessory: .external)
            }
            Link(destination: FounderLinks.helplines) {
                SettingsRowLabel(title: "Find a free helpline near you", systemImage: "lifepreserver.fill", tint: Palette.ember, accessory: .external)
            }
            ShareLink(item: shareMessage) {
                SettingsRowLabel(title: "Tell a friend", systemImage: "heart.fill", tint: Palette.rose)
            }
            Button(action: rateApp) {
                SettingsRowLabel(title: "Rate Unhook", systemImage: "star.fill", tint: Palette.sun)
            }
        } header: {
            SettingsSectionHeader(title: "Support", systemImage: "heart.fill", tint: Palette.rose)
        } footer: {
            footerText(Text("Unhook is a self-help tool, not a substitute for professional care. If you're struggling, please reach out to a doctor or a helpline."))
        }
        .settingsGlassRows()
    }

    private var privacySection: some View {
        Section {
            appLockToggle
            privacyPromise
            Button {
                Haptics.tap()
                showingPrivacyPolicy = true
            } label: {
                SettingsRowLabel(title: "Privacy Policy", systemImage: "hand.raised.fill", tint: Palette.amber, accessory: .chevron)
            }
            Link(destination: FounderLinks.privacyPolicy) {
                SettingsRowLabel(title: "Privacy Policy website", systemImage: "globe", tint: Palette.sky, accessory: .external)
            }
        } header: {
            SettingsSectionHeader(title: "Privacy & security", systemImage: "lock.shield.fill", tint: Palette.mint)
        } footer: {
            footerText(Text(appLockFooter))
        }
        .settingsGlassRows()
    }

    private var dataSection: some View {
        Section {
            Button(action: exportData) {
                SettingsRowLabel(title: "Export my data", systemImage: "square.and.arrow.up", tint: Palette.sky)
            }
            Button(role: .destructive) {
                confirmingErase = true
            } label: {
                SettingsRowLabel(title: "Erase all data", systemImage: "trash.fill", tint: Palette.rose, titleColor: Palette.rose)
            }
        } header: {
            SettingsSectionHeader(title: "Your data", systemImage: "tray.full.fill", tint: Palette.sky)
        } footer: {
            footerText(Text("Export a copy of everything you've tracked as a file you can save or share. Erasing deletes it all from this device."))
        }
        .settingsGlassRows()
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(appVersion)
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
            } label: {
                SettingsRowLabel(title: "Version", systemImage: "info.circle.fill", tint: Palette.sky)
            }
        } header: {
            SettingsSectionHeader(title: "About", systemImage: "sparkles", tint: Palette.sun)
        } footer: {
            madeInIowa
        }
        .settingsGlassRows()
    }

    // MARK: Rows

    private var proActiveRow: some View {
        LabeledContent {
            Text("Active")
                .foregroundStyle(Palette.mint)
        } label: {
            SettingsRowLabel(title: "Unhook Pro", systemImage: "crown.fill", tint: Palette.amber)
        }
    }

    private var upgradeRow: some View {
        Button {
            Haptics.tap()
            router.showPaywall(.settings)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.inkText)
                    .frame(width: upgradeIconSize, height: upgradeIconSize)
                    .background(Brand.gradient, in: RoundedRectangle(cornerRadius: upgradeIconSize * 0.27, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Unlimited habits and goals, and deeper insights.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await restorePurchases() }
        } label: {
            HStack {
                SettingsRowLabel(title: "Restore purchases", systemImage: "arrow.clockwise", tint: Palette.sky)
                Spacer()
                if isRestoring {
                    ProgressView()
                }
            }
        }
        .disabled(isRestoring || store.isPurchasing)
    }

    private var appLockToggle: some View {
        Toggle(isOn: appLockBinding) {
            SettingsRowLabel(title: "Lock with \(appLockMethod.kindName)", systemImage: appLockMethod.systemImage, tint: Palette.violet)
        }
        // Stays switchable while on, so the lock can always be turned off.
        .disabled(isEnablingAppLock || (!canUseAppLock && !appLockEnabled))
    }

    private var privacyPromise: some View {
        SettingsRowLabel(
            title: "Your data stays on your device",
            systemImage: "lock.shield.fill",
            tint: Palette.mint,
            subtitle: "No account, no tracking, no ads. Unhook never sends your habits anywhere."
        )
        .accessibilityElement(children: .combine)
    }

    private var madeInIowa: some View {
        Text("Made with \(heartSymbol) in Iowa by Bruce Gao")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .accessibilityLabel(Text("Made with love in Iowa by Bruce Gao"))
    }

    private var heartSymbol: Text {
        Text(Image(systemName: "heart.fill")).foregroundStyle(Palette.rose)
    }

    private func footerText(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
    }

    // MARK: Helpers

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? AppSettings.defaultReminderHour
            reminderMinute = components.minute ?? AppSettings.defaultReminderMinute
            NotificationManager.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
        }
    }

    /// Shows the lock as on while it's being confirmed, and only turns it on once the owner authenticates.
    private var appLockBinding: Binding<Bool> {
        Binding {
            appLockEnabled || isEnablingAppLock
        } set: { isOn in
            if isOn {
                guard !appLockEnabled, !isEnablingAppLock else { return }
                // Set before the prompt so the switch doesn't flick back off while it appears.
                isEnablingAppLock = true
                Task { await confirmAndEnableAppLock() }
            } else {
                appLockEnabled = false
            }
        }
    }

    private var isShowingAlert: Binding<Bool> {
        Binding {
            alert != nil
        } set: { isPresented in
            if !isPresented {
                alert = nil
            }
        }
    }

    private var appLockFooter: String {
        if !canUseAppLock && !appLockEnabled {
            return String(localized: "To lock Unhook, set up a passcode in the Settings app first.")
        }
        return String(localized: "Unhook asks for \(appLockMethod.inlineName) each time you come back, and hides your progress in the app switcher.")
    }

    private var hasActiveSubscription: Bool {
        store.purchasedProductIDs.contains(Store.ProductID.yearly)
            || store.purchasedProductIDs.contains(Store.ProductID.monthly)
    }

    private var currencyOptions: [String] {
        Self.currencies.contains(currencyCode) ? Self.currencies : [currencyCode] + Self.currencies
    }

    private func currencyLabel(_ code: String) -> String {
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return "\(code) · \(name)"
    }

    private var shareMessage: String {
        String(localized: "I'm breaking my bad habits with Unhook, one day at a time. 💪")
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshAppLockAvailability() {
        appLockMethod = AppLockSettings.currentMethod()
        canUseAppLock = AppLockSettings.canAuthenticate()
    }

    // MARK: Actions

    private func updateReminder(enabled: Bool) async {
        guard enabled else {
            NotificationManager.cancelDailyReminder()
            return
        }
        if await NotificationManager.requestAuthorization() {
            notificationsDenied = false
            NotificationManager.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
        } else {
            notificationsDenied = true
            reminderEnabled = false
        }
    }

    private func updateMilestoneAlerts(enabled: Bool) async {
        guard enabled else {
            for habit in habits {
                NotificationManager.cancelMilestones(for: habit.uuid)
            }
            return
        }
        if await NotificationManager.requestAuthorization() {
            notificationsDenied = false
            for habit in habits {
                NotificationManager.scheduleMilestones(for: habit)
            }
        } else {
            notificationsDenied = true
            milestoneAlertsEnabled = false
        }
    }

    private func restorePurchases() async {
        guard !isRestoring else { return }
        Haptics.tap()
        isRestoring = true
        // Only report errors from this restore, not an older one (a failed product load at launch, say).
        store.lastErrorMessage = nil
        let outcome = await store.restorePurchases()
        isRestoring = false

        switch outcome {
        case .restored:
            Haptics.success()
            alert = SettingsAlert(
                title: String(localized: "Purchases restored"),
                message: String(localized: "Unhook Pro is active. Thank you for supporting Unhook! 💜")
            )
        case .failed:
            let message = store.lastErrorMessage ?? ""
            store.lastErrorMessage = nil
            alert = SettingsAlert(title: String(localized: "Couldn't restore purchases"), message: message)
        case .nothingFound:
            alert = SettingsAlert(
                title: String(localized: "No purchases found"),
                message: String(localized: "We couldn't find an earlier Unhook Pro purchase for this Apple ID. Purchases are restored for the Apple ID you're signed in with.")
            )
        case .cancelled:
            // The user closed the Apple ID prompt; nothing to report.
            break
        }
    }

    private func confirmAndEnableAppLock() async {
        let result = await AppLockSettings.authenticate(
            reason: String(localized: "Confirm it's you to turn on the app lock.")
        )
        isEnablingAppLock = false

        switch result {
        case .success:
            appLockEnabled = true
            // Milestone alerts are worded when they're scheduled. Reword the pending ones now, so they stop naming
            // the habit on the Lock Screen.
            for habit in habits {
                NotificationManager.scheduleMilestones(for: habit)
            }
            Haptics.success()
        case .cancelled:
            break
        case .passcodeNotSet:
            canUseAppLock = false
            alert = SettingsAlert(
                title: String(localized: "Set up a passcode first"),
                message: String(localized: "To lock Unhook, turn on a passcode in the Settings app, then try again.")
            )
        case .failed(let message):
            alert = SettingsAlert(title: String(localized: "Couldn't turn on the lock"), message: message)
        }
    }

    private func exportData() {
        Haptics.tap()
        do {
            let json = try DataExporter.writeExportFile(context: context)
            // The spreadsheet copy is a bonus; the JSON alone is a complete export.
            let csv = try? DataExporter.writeCSVFile(context: context)
            exportFiles = DataExportFiles(json: json, csv: csv)
        } catch {
            alert = SettingsAlert(title: String(localized: "Couldn't export your data"), message: error.localizedDescription)
        }
    }

    private func rateApp() {
        // A manual request uses up one of the system's few prompts, so hold off on the automatic one.
        ReviewPrompter.standard.markRequested()
        requestReview()
    }

    /// The toggles can be on while the system permission was never granted (the user chose "Maybe later"
    /// in onboarding, or turned notifications off in the Settings app). Say so instead of failing silently.
    private func refreshNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let allowed = status == .authorized || status == .provisional || status == .ephemeral
        notificationsDenied = !allowed && (reminderEnabled || milestoneAlertsEnabled)
    }

    private func turnOnNotifications() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined {
            if await NotificationManager.requestAuthorization() {
                notificationsDenied = false
                if reminderEnabled {
                    NotificationManager.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
                }
                for habit in habits {
                    NotificationManager.scheduleMilestones(for: habit)
                }
            }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            _ = await UIApplication.shared.open(url)
        }
    }

    private func eraseAll() {
        // Drop anything still pointing at the habits about to be deleted.
        router.celebration = nil
        NotificationManager.cancelAll()
        relapses.forEach { context.delete($0) }
        urges.forEach { context.delete($0) }
        pledges.forEach { context.delete($0) }
        habits.forEach { context.delete($0) }
        savingsGoals.forEach { context.delete($0) }
        // Daily missions and the 30-day challenge aren't queried here, so fetch them to delete them too.
        deleteAll(MissionCompletion.self)
        deleteAll(ChallengeProgress.self)
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to erase data: \(error)")
        }
        // Ranks and achievements remember what was already celebrated; start those from scratch as well.
        for key in Self.engagementDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // An earlier export would still hold everything that was just erased.
        DataExporter.removeExportFiles()
        exportFiles = nil
        reminderEnabled = false
        dataResetCount += 1
        Haptics.warning()
    }

    /// Deletes every saved record of a model type this screen doesn't query.
    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) {
        guard let models = try? context.fetch(FetchDescriptor<Model>()) else { return }
        for model in models {
            context.delete(model)
        }
    }
}

// MARK: - Row styling

/// A settings row: a tinted icon badge, a title with an optional detail line, and an optional trailing hint.
private struct SettingsRowLabel: View {
    enum Accessory {
        case chevron, external
    }

    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = Palette.amber
    var subtitle: LocalizedStringKey?
    var accessory: Accessory?
    var titleColor: Color = Palette.textPrimary

    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: systemImage, tint: tint, size: badgeSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Separators start under the text, not under the badge.
            .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                dimensions[.leading]
            }
            if let accessory {
                Spacer(minLength: 8)
                Image(systemName: accessory == .chevron ? "chevron.right" : "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A Form section header in the app's rounded type, with a small tinted symbol.
private struct SettingsSectionHeader: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = Palette.amber

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    /// Frosted glass rows with soft separators, for every section on the night background.
    func settingsGlassRows() -> some View {
        listRowBackground(Palette.surface.opacity(0.72))
            .listRowSeparatorTint(Palette.hairline)
    }
}

#Preview {
    SettingsView()
        .previewEnvironment()
}

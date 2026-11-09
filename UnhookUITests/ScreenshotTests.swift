import XCTest

/// Walks through every main screen with sample data, checks each one appears, and saves a screenshot of it.
///
/// The CI screenshot workflow runs this on the largest iPhone simulator. Screenshots are written as PNGs to the
/// folder in the SCREENSHOT_DIR environment variable (pass it to xcodebuild as TEST_RUNNER_SCREENSHOT_DIR) and are
/// also attached to the test results. Tests are independent: each one launches the app fresh.
final class ScreenshotTests: XCTestCase {

    // MARK: Main screens

    @MainActor
    func test01Today() {
        let app = launch()
        XCTAssertTrue(app.buttons["habitCard"].firstMatch.waitForExistence(timeout: 10), "Today shows the habit cards")
        snap("01-today", app)
        app.swipeUp()
        snap("02-today-more", app)
        app.swipeUp()
        snap("03-today-bottom", app)
    }

    @MainActor
    func test02HabitDetail() {
        let app = launch()
        let card = app.buttons["habitCard"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Today shows the habit cards")
        card.tap()
        pause(1.2)
        snap("04-habit-detail", app)
        app.swipeUp()
        snap("05-habit-detail-more", app)
        app.swipeUp()
        snap("06-habit-detail-bottom", app)
    }

    @MainActor
    func test03SOS() {
        let app = launch(screen: "sos")
        pause(2)
        snap("07-sos", app)
        pause(5)
        snap("08-sos-breathing", app)
    }

    @MainActor
    func test04Coach() {
        let app = launch()
        let entry = app.buttons["coachEntry"].firstMatch
        if scrollTo(entry, in: app) {
            entry.tap()
            pause(1.5)
            snap("09-coach", app)
        } else {
            XCTFail("The coach card is on Today")
        }
    }

    @MainActor
    func test05Progress() {
        let app = launch(screen: "progress")
        pause(1.5)
        snap("10-progress", app)
        app.swipeUp()
        snap("11-progress-more", app)
        app.swipeUp()
        snap("12-progress-bottom", app)
    }

    @MainActor
    func test06Goals() {
        let app = launch()
        let allGoals = app.buttons["allGoalsButton"].firstMatch
        if scrollTo(allGoals, in: app) {
            allGoals.tap()
            pause(1.2)
            snap("13-goals", app)
        } else {
            XCTFail("The savings goals card is on Today")
        }
    }

    @MainActor
    func test07Settings() {
        let app = launch(screen: "settings")
        pause(1.2)
        snap("14-settings", app)
        app.swipeUp()
        snap("15-settings-more", app)
        app.swipeUp()
        snap("16-settings-bottom", app)
    }

    @MainActor
    func test08Celebration() {
        let app = launch(screen: "celebration")
        pause(3)
        snap("17-celebration", app)
    }

    @MainActor
    func test09AddHabit() {
        let app = launch()
        let add = app.buttons["addHabitButton"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Today has an add button")
        add.tap()
        pause(1.2)
        snap("18-add-habit", app)
    }

    @MainActor
    func test10Founder() {
        let app = launch(screen: "settings")
        let row = app.buttons["founderRow"].firstMatch
        if scrollTo(row, in: app) {
            row.tap()
            pause(1.5)
            snap("19-founder", app)
            app.swipeUp()
            snap("20-founder-more", app)
        } else {
            XCTFail("Settings links to the founder page")
        }
    }

    @MainActor
    func test11Challenge() {
        let app = launch()
        app.open(URL(string: "unhook://challenge/reset30")!)
        pause(2)
        snap("21-challenge", app)
    }

    // MARK: First run

    @MainActor
    func test12Onboarding() {
        let app = launch(onboarded: false, seed: false)
        pause(1.5)
        snap("30-onboarding-welcome", app)
        tap(["Get started", "Start", "Continue"], in: app)
        pause(1)
        snap("31-onboarding-habit", app)
        tap(["Smoking", "🚬 Smoking", "Vaping"], in: app, partial: true)
        pause(1)
        snap("32-onboarding-quit-date", app)
        tap(["Just now"], in: app, partial: true, required: false)
        tap(["Continue"], in: app)
        pause(1)
        snap("33-onboarding-cost", app)
        tap(["Continue"], in: app)
        pause(1)
        snap("34-onboarding-reasons", app)
        tap(["Continue", "Skip for now", "Skip", "Next"], in: app, partial: true)
        pause(1.5)
        snap("35-onboarding-projection", app)
        tap(["Let's do this", "Continue"], in: app)
        pause(1)
        snap("36-onboarding-reminders", app)
        tap(["Maybe later", "Not now", "Skip"], in: app)
        pause(2)
        snap("37-after-onboarding", app)
        XCTAssertTrue(app.buttons["habitCard"].firstMatch.waitForExistence(timeout: 10), "Onboarding ends on Today with the new habit")
    }

    // MARK: Helpers

    /// Launches a fresh copy of the app with in-memory data, in English, with the given screen open.
    @MainActor
    private func launch(screen: String? = nil, onboarded: Bool = true, seed: Bool = true) -> XCUIApplication {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments += [
            "-UITest",
            "-hasOnboarded", onboarded ? "YES" : "NO",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // Morning, so Today greets with "Good morning" in screenshots wherever the CI machine is.
            "-UITestHour", "10",
        ]
        if seed {
            app.launchArguments.append("-UITestSeed")
        }
        if let screen {
            app.launchArguments += ["-UITestScreen", screen]
        }
        app.launch()
        return app
    }

    /// Saves a screenshot to SCREENSHOT_DIR and attaches it to the test results.
    @MainActor
    private func snap(_ name: String, _ app: XCUIApplication, settle: TimeInterval = 1.2) {
        pause(settle)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let folder = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !folder.isEmpty else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }

    /// Waits without blocking the test runner's event handling.
    private func pause(_ seconds: TimeInterval) {
        let never = XCTestExpectation(description: "pause")
        never.isInverted = true
        _ = XCTWaiter.wait(for: [never], timeout: seconds)
    }

    /// Scrolls the current screen until the element is on screen. Returns false if it never appears.
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 6) && element.isHittable { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.exists && element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }

    /// Taps the first button whose label matches one of `labels` (or contains it, with `partial`).
    @MainActor
    private func tap(_ labels: [String], in app: XCUIApplication, partial: Bool = false, required: Bool = true) {
        for label in labels {
            let button: XCUIElement
            if partial {
                button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
            } else {
                button = app.buttons[label].firstMatch
            }
            if button.waitForExistence(timeout: 2) {
                if !button.isHittable {
                    _ = scrollTo(button, in: app, maxSwipes: 3)
                }
                button.tap()
                return
            }
        }
        if required {
            XCTFail("No button labeled \(labels.joined(separator: " / ")) on this screen")
        }
    }
}

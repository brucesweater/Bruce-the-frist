import Foundation
import SwiftData
import Testing
@testable import Unhook

struct DataExporterTests {
    private static let day: TimeInterval = 86_400
    /// 2026-10-24 12:00:00 UTC. Whole seconds, so it survives ISO 8601 exactly.
    private static let now = Date(timeIntervalSince1970: 1_792_843_200)

    private static func timeZone(_ identifier: String) throws -> TimeZone {
        try #require(TimeZone(identifier: identifier))
    }

    /// Two habits with history, a craving logged without a habit, three pledges and two savings goals
    /// (one of them bought).
    private static func populate(_ context: ModelContext) throws {
        let smoking = Habit(
            name: "Smoking", emoji: "🚬", theme: .fire,
            streakStart: now.addingTimeInterval(-30 * day),
            dailyCost: 12, dailyMinutes: 60, unitsPerDay: 15, unitName: "cigarettes",
            reasons: ["Breathe easier"],
            sortIndex: 0,
            presetID: "smoking"
        )
        let sugar = Habit(name: "Sugar", emoji: "🍭", theme: .candy, streakStart: now.addingTimeInterval(-5 * day), sortIndex: 1)
        context.insert(smoking)
        context.insert(sugar)

        smoking.recordRelapse(at: now.addingTimeInterval(-20 * day), note: "Rough day, \"really\" rough", trigger: .stress, in: context)
        smoking.recordRelapse(at: now.addingTimeInterval(-10 * day), in: context)

        for offset in 1...3 {
            let urge = Urge(
                date: now.addingTimeInterval(-Double(offset) * day),
                resisted: offset != 3,
                trigger: .boredom,
                intensity: offset
            )
            context.insert(urge)
            smoking.urges.append(urge)
        }
        // Logged from SOS while several habits are tracked, so it belongs to no habit.
        context.insert(Urge(date: now.addingTimeInterval(-3_600), resisted: true))

        for offset in 0..<3 {
            context.insert(Pledge(day: now.addingTimeInterval(-Double(offset) * day), mood: 3 + offset))
        }

        let trip = SavingsGoal(title: "Trip, to Japan", emoji: "🗾", cost: 1_200, sortIndex: 0)
        let shoes = SavingsGoal(title: "Running shoes", emoji: "👟", cost: 140, sortIndex: 1)
        shoes.redeemedAt = now.addingTimeInterval(-day)
        context.insert(trip)
        context.insert(shoes)
        try context.save()
    }

    // MARK: JSON

    @Test func jsonDecodesBackWithEverything() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try Self.populate(context)

        let archive = try DataExporter.decodeArchive(from: DataExporter.exportJSON(context: context, now: Self.now))

        #expect(archive.formatVersion == DataExporter.formatVersion)
        #expect(archive.exportedAt == Self.now)
        // Money amounts are only meaningful with their currency.
        #expect(!archive.currencyCode.isEmpty)
        #expect(archive.habits.map(\.name) == ["Smoking", "Sugar"])
        let smoking = try #require(archive.habits.first)
        #expect(smoking.relapses.count == 2)
        #expect(smoking.urges.count == 3)
        let sugar = try #require(archive.habits.last)
        #expect(sugar.relapses.isEmpty)
        #expect(sugar.urges.isEmpty)
        #expect(archive.unassignedUrges.count == 1)
        #expect(archive.pledges.count == 3)
        #expect(archive.savingsGoals.count == 2)
    }

    @Test func recordsKeepTheDetails() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try Self.populate(context)

        let archive = try DataExporter.decodeArchive(from: DataExporter.exportJSON(context: context, now: Self.now))
        let smoking = try #require(archive.habits.first)

        #expect(smoking.presetID == "smoking")
        #expect(smoking.theme == "fire")
        #expect(smoking.reasons == ["Breathe easier"])
        #expect(smoking.unitName == "cigarettes")
        #expect(smoking.currentStreakSeconds == 10 * Self.day)
        #expect(smoking.bankedSeconds == 20 * Self.day)

        // Oldest first, with the trigger and note of the first slip.
        let firstSlip = try #require(smoking.relapses.first)
        let secondSlip = try #require(smoking.relapses.last)
        #expect(firstSlip.date < secondSlip.date)
        #expect(firstSlip.trigger == "stress")
        #expect(firstSlip.note == "Rough day, \"really\" rough")
        #expect(secondSlip.trigger == nil)

        #expect(smoking.urges.map(\.intensity) == [3, 2, 1])
        #expect(smoking.urges.filter(\.resisted).count == 2)
        #expect(smoking.urges.allSatisfy { $0.trigger == "boredom" })
        let unassigned = try #require(archive.unassignedUrges.first)
        #expect(unassigned.intensity == nil)
        #expect(unassigned.trigger == nil)

        #expect(archive.pledges.map(\.mood) == [5, 4, 3])

        try #require(archive.savingsGoals.count == 2)
        #expect(archive.savingsGoals.map(\.title) == ["Trip, to Japan", "Running shoes"])
        #expect(archive.savingsGoals[0].redeemedAt == nil)
        #expect(archive.savingsGoals[1].redeemedAt == Self.now.addingTimeInterval(-Self.day))
        #expect(archive.savingsGoals[1].cost == 140)
    }

    @Test func jsonUsesISO8601Dates() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        let data = try DataExporter.exportJSON(context: context, now: Self.now)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.contains("2026-10-24T12:00:00Z"))
        #expect(text.contains("\n"))
    }

    @Test func emptyStoreExportsEmptyLists() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        let archive = try DataExporter.decodeArchive(from: DataExporter.exportJSON(context: context, now: Self.now))

        #expect(archive.habits.isEmpty)
        #expect(archive.unassignedUrges.isEmpty)
        #expect(archive.pledges.isEmpty)
        #expect(archive.savingsGoals.isEmpty)
        #expect(archive.missionCompletions?.isEmpty == true)
        #expect(archive.challengeRuns?.isEmpty == true)
        let csv = try DataExporter.exportCSV(context: context)
        #expect(csv == DataExporter.csvHeader + "\r\n")
    }

    @Test func nonFiniteNumbersExportAsZero() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let habit = Habit(
            name: "Big spender", emoji: "💸", theme: .gold,
            streakStart: Self.now.addingTimeInterval(-Self.day),
            dailyCost: .infinity
        )
        context.insert(habit)

        let archive = try DataExporter.decodeArchive(from: DataExporter.exportJSON(context: context, now: Self.now))
        let exported = try #require(archive.habits.first)

        #expect(exported.dailyCost == 0)
        #expect(exported.moneySaved == 0)
        let csv = try DataExporter.exportCSV(context: context)
        #expect(!csv.contains("inf"))
    }

    // MARK: CSV

    @Test func csvHasOneRowPerEventOldestFirst() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try Self.populate(context)

        let csv = try DataExporter.exportCSV(context: context, timeZone: Self.timeZone("UTC"))
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        #expect(lines.first == DataExporter.csvHeader)
        // 2 habits added, 2 slips, 4 cravings, 3 pledges, 2 goals added and 1 goal bought.
        #expect(lines.count == 1 + 14)
        let rows = Array(lines.dropFirst())
        #expect(rows.filter { $0.contains(",habit_added,") }.count == 2)
        #expect(rows.filter { $0.contains(",slip,") }.count == 2)
        #expect(rows.filter { $0.contains(",craving_resisted,") }.count == 3)
        #expect(rows.filter { $0.contains(",craving,") }.count == 1)
        #expect(rows.filter { $0.contains(",pledge,") }.count == 3)
        #expect(rows.filter { $0.contains(",goal_added,") }.count == 2)
        #expect(rows.filter { $0.contains(",goal_redeemed,") }.count == 1)

        // ISO 8601 in one time zone sorts the same as the dates themselves.
        let dates = rows.map { row in String(row.prefix { $0 != "," }) }
        #expect(dates == dates.sorted())
    }

    @Test func csvRowsCarryTheirDetails() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try Self.populate(context)

        let csv = try DataExporter.exportCSV(context: context, timeZone: Self.timeZone("UTC"))

        #expect(csv.contains("2026-10-04T12:00:00Z,slip,Smoking,\"streak: 10d 0h; trigger: stress; note: Rough day, \"\"really\"\" rough\""))
        #expect(csv.contains("2026-10-14T12:00:00Z,slip,Smoking,streak: 10d 0h\r\n"))
        #expect(csv.contains("2026-10-21T12:00:00Z,craving,Smoking,trigger: boredom; intensity: 3/5\r\n"))
        #expect(csv.contains("2026-10-24T11:00:00Z,craving_resisted,,\r\n"))
        #expect(csv.contains(",goal_redeemed,,👟 Running shoes; cost: 140\r\n"))
        #expect(csv.contains(",goal_added,,\"🗾 Trip, to Japan; cost: 1200\"\r\n"))
    }

    @Test func csvFieldsAreEscaped() {
        #expect(DataExporter.csvField("plain") == "plain")
        #expect(DataExporter.csvField("") == "")
        #expect(DataExporter.csvField("a,b") == "\"a,b\"")
        #expect(DataExporter.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(DataExporter.csvField("two\nlines") == "\"two\nlines\"")
        #expect(DataExporter.csvField("two\r\nlines") == "\"two\r\nlines\"")
    }

    @Test func csvFieldsNeverRunAsFormulas() {
        #expect(DataExporter.csvField("=SUM(A1:A9)") == "'=SUM(A1:A9)")
        #expect(DataExporter.csvField("+1") == "'+1")
        #expect(DataExporter.csvField("-1") == "'-1")
        #expect(DataExporter.csvField("@home") == "'@home")
        #expect(DataExporter.csvField("=A1,B1") == "\"'=A1,B1\"")
        #expect(DataExporter.csvField("a=b") == "a=b")
    }

    // MARK: Missions and the 30-Day Reset

    @Test func missionsAndResetRunsAreExported() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        // Stored days are 00:00 UTC on their date. A mission checked off this morning, and a Reset that started four
        // days ago and was left yesterday with days 1, 2 and 4 done.
        let today = Self.now.addingTimeInterval(-12 * 3_600)
        let startDay = today.addingTimeInterval(-4 * Self.day)
        let checkedAt = Self.now.addingTimeInterval(-3_600)
        let joinedAt = startDay.addingTimeInterval(9 * 3_600)
        let leftAt = Self.now.addingTimeInterval(-Self.day)
        context.insert(MissionCompletion(day: today, missionID: "walk", completedAt: checkedAt))
        let progress = ChallengeProgress(challengeID: ResetChallenge.id, startDay: startDay)
        // Set by hand, because the initializer stamps the current time.
        progress.joinedAt = joinedAt
        progress.completedDays = [1, 2, 4]
        progress.leftAt = leftAt
        context.insert(progress)
        try context.save()

        let data = try DataExporter.exportJSON(context: context, now: Self.now)
        let text = try #require(String(data: data, encoding: .utf8))
        // Stored days are exported as they are stored.
        #expect(text.contains("2026-10-24T00:00:00Z"))
        #expect(text.contains("2026-10-20T00:00:00Z"))

        let archive = try DataExporter.decodeArchive(from: data)
        let missions = try #require(archive.missionCompletions)
        let runs = try #require(archive.challengeRuns)
        #expect(missions.count == 1)
        #expect(runs.count == 1)
        let mission = try #require(missions.first)
        #expect(mission.day == today)
        #expect(mission.missionID == "walk")
        #expect(mission.completedAt == checkedAt)
        let run = try #require(runs.first)
        #expect(run.challengeID == ResetChallenge.id)
        #expect(run.startDay == startDay)
        #expect(run.completedDays == [1, 2, 4])
        #expect(run.joinedAt == joinedAt)
        #expect(run.finishedAt == nil)
        #expect(run.leftAt == leftAt)

        let csv = try DataExporter.exportCSV(context: context, timeZone: Self.timeZone("UTC"))
        let expected = [
            DataExporter.csvHeader,
            "2026-10-20T09:00:00Z,challenge_joined,,challenge: reset30; days done: 1 2 4",
            "2026-10-23T12:00:00Z,challenge_left,,challenge: reset30; days done: 1 2 4",
            "2026-10-24T11:00:00Z,mission_completed,,mission: walk",
        ]
        #expect(csv == expected.joined(separator: "\r\n") + "\r\n")
    }

    @Test func formatOneFilesStillDecode() throws {
        // Written before mission check-offs and Reset runs were part of the export.
        let json = """
        {
          "appVersion" : "1.0",
          "currencyCode" : "USD",
          "exportedAt" : "2026-10-24T12:00:00Z",
          "formatVersion" : 1,
          "habits" : [],
          "pledges" : [],
          "savingsGoals" : [],
          "unassignedUrges" : []
        }
        """
        let archive = try DataExporter.decodeArchive(from: Data(json.utf8))

        #expect(archive.formatVersion == 1)
        #expect(archive.missionCompletions == nil)
        #expect(archive.challengeRuns == nil)
        #expect(DataExporter.csv(for: archive) == DataExporter.csvHeader + "\r\n")
    }

    // MARK: Files

    @Test func fileNameUsesTheGregorianDateInTheGivenTimeZone() throws {
        let utc = try Self.timeZone("UTC")
        let tokyo = try Self.timeZone("Asia/Tokyo")
        #expect(DataExporter.fileName(for: Self.now, timeZone: utc) == "Unhook-Export-2026-10-24.json")
        #expect(DataExporter.fileName(for: Self.now, fileExtension: "csv", timeZone: utc) == "Unhook-Export-2026-10-24.csv")
        // 16:00 UTC is already 01:00 the next day in Tokyo.
        let late = Self.now.addingTimeInterval(4 * 3_600)
        #expect(DataExporter.fileName(for: late, timeZone: utc) == "Unhook-Export-2026-10-24.json")
        #expect(DataExporter.fileName(for: late, timeZone: tokyo) == "Unhook-Export-2026-10-25.json")
    }

    @Test func writesExportFilesToTheTemporaryDirectoryAndCleansUp() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try Self.populate(context)

        let jsonURL = try DataExporter.writeExportFile(context: context, now: Self.now)
        let csvURL = try DataExporter.writeCSVFile(context: context, now: Self.now)
        defer {
            try? FileManager.default.removeItem(at: jsonURL)
            try? FileManager.default.removeItem(at: csvURL)
        }

        #expect(jsonURL.lastPathComponent == DataExporter.fileName(for: Self.now))
        #expect(csvURL.lastPathComponent == DataExporter.fileName(for: Self.now, fileExtension: "csv"))
        let temporaryPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        #expect(jsonURL.deletingLastPathComponent().standardizedFileURL.path == temporaryPath)

        let archive = try DataExporter.decodeArchive(from: Data(contentsOf: jsonURL))
        #expect(archive.habits.count == 2)
        #expect(archive.savingsGoals.count == 2)

        // The CSV starts with a UTF-8 byte-order mark so spreadsheet apps keep the emoji.
        let csvData = try Data(contentsOf: csvURL)
        #expect(Array(csvData.prefix(3)) == [0xEF, 0xBB, 0xBF])

        DataExporter.removeExportFiles()
        #expect(!FileManager.default.fileExists(atPath: jsonURL.path))
        #expect(!FileManager.default.fileExists(atPath: csvURL.path))
    }

    // MARK: App lock

    @Test func appLockMethodNames() {
        #expect(AppLockMethod.faceID.kindName == "Face ID")
        #expect(AppLockMethod.touchID.kindName == "Touch ID")
        #expect(AppLockMethod.passcode.kindName == "Passcode")
        #expect(AppLockMethod.faceID.systemImage == "faceid")
        #expect(AppLockMethod.touchID.systemImage == "touchid")
    }

    @Test func biometricsAvailabilityMatchesTheMethod() {
        let method = AppLockSettings.currentMethod()
        let biometrics = AppLockSettings.canUseBiometrics()
        #expect(biometrics.available == (method != .passcode))
        #expect(biometrics.kindName == method.kindName)
    }
}

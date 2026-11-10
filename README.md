# Unhook: quit anything, one day at a time

<img src="Unhook/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" align="right" alt="Unhook app icon" />

**Unhook** is an iPhone app that helps people break bad habits: smoking, vaping, alcohol, doomscrolling, sugar, porn, gambling, or anything else. It counts every second you stay free, shows the money and time you win back, explains what's recovering in your body and mind, and gets you through cravings with about a minute of SOS breathing and a private coach.

**Version 1.0 is free.** No in-app purchases, no ads, no account, no server and no analytics. Everything stays on the iPhone.

- **iPhone only**, iOS 17 and later.
- **English** at launch. More languages are planned for an update.
- **The "Dawn" design:** always dark, a night sky that turns to sunrise. The orb on the Today screen brightens as you get closer to your next milestone.

It's built with SwiftUI, SwiftData, Swift Charts, App Intents, WidgetKit and Apple's on-device Foundation Models, with no third-party code. Bruce Gao, a high school senior in West Des Moines, Iowa, designed it and built it with AI-assisted coding (Claude Code).

---

## The growth plan, built into the product

| Stage | What the app does |
|---|---|
| **Activation** | Onboarding asks what you're quitting, what it costs and why, then shows what you'll save in a year before starting your first counter. |
| **Daily habit** | A live clean-time counter, money saved ticking up, three daily missions, a daily pledge with a mood check-in, a tip of the day, reminders, and Home Screen and Lock Screen widgets. |
| **Motivation** | 13 milestones with full-screen celebrations, XP and 12 ranks with a rank-up celebration, the 30-Day Reset challenge, achievements, a recovery timeline for every habit, and savings goals. |
| **Retention** | SOS breathing for cravings, the on-device coach, trigger insights ("cravings peak around 9 PM"), and a kind slip flow that never erases progress (with Undo for slips logged by mistake). |
| **Word of mouth** | Shareable progress cards, a founder page, and App Store review prompts timed to high points. |
| **Discovery** | Siri, Spotlight and Action button shortcuts, and an App Store in-app event for the 30-Day Reset. |
| **Price** | **Free.** No in-app purchases and no ads. The Unhook Pro code is still in the project but switched off (see [Unhook Pro](#unhook-pro-switched-off)). |
| **Trust** | Face ID lock, data export and erase-all, an in-app privacy policy, privacy manifests, no tracking, no account and no server. |

## Features

**Quit and track**

- **Onboarding:** your habit, when you quit ("Just now" or "Earlier", with a date), daily cost and time, your reasons, a one-year projection, and a reminders opt-in.
- **Clean-time counters** for each habit: days, hours, minutes and seconds, with 13 milestones (1 hour to 5 years), milestone alerts and a full-screen celebration for each one.
- **Money, time and units saved,** plus **savings goals** funded in order from what you've saved. Preset costs start in your local currency.
- **Recovery timeline** for each habit type, worded cautiously. The smoking timeline is adapted from public WHO and NHS pages, and the app says it is not connected to them. Every timeline says it's general information, not medical advice, and to check with a doctor. Choosing alcohol (in onboarding or when adding a habit) shows a warning that stopping heavy daily drinking suddenly can be dangerous.
- **A kind slip flow** that banks your earlier clean time, with **Undo**.

**Get through cravings**

- **SOS:** about a minute of guided breathing (four breaths: in for 4 seconds, hold for 4, out for 6) with your own reasons, then "What set it off?" and "How strong was it?".
- **The coach:** Apple's on-device Foundation Models on iOS 26 with Apple Intelligence, and replies built into the app on every other iPhone. Messages never leave the phone and aren't saved.
  - Crisis messages get a fixed, caring reply and a findahelpline.com link. Detection recognizes phrases in many languages (`CoachSafety.swift`), but the fixed reply is in English.
  - Messages that describe a possible medical emergency are told to call emergency services.
  - If Apple's guardrails block a reply, the coach shows a caring message and the helpline banner instead.
  - Every coach reply can be reported by email: touch and hold it, then choose "Report this reply".

**Come back every day**

- **XP and 12 ranks** (Midnight to Legend), with a celebration when you rank up.
- **Three daily missions,** with a bonus for completing all three (a perfect day).
- **Daily pledge** with a mood check-in, and **achievements**.
- **The 30-Day Reset:** one small step a day for 30 days. It also opens from `unhook://challenge/reset30`, the link the in-app event uses.
- **Progress tab:** rank card, clean-days calendar, craving and mood charts, trigger insights and achievements.

**Around the app**

- **Opening:** a short animation of the icon's ring opening and the sky turning to dawn each time the app starts. A tap skips it, it doesn't play when the app is opened for SOS or from a link, and with Reduce Motion on it's a simple fade. In a Debug build, `-OpeningTime 0.9` holds it at one moment.
- **Widgets:** Streak (Home Screen small and medium, Lock Screen circular, rectangular and inline) and Craving SOS (one tap to breathing). They read the app's data through an App Group.
- **Siri and Shortcuts:** "Open SOS in Unhook", "I beat a craving in Unhook", "Check my streak in Unhook".
- **Face ID lock.** When it's on, widgets and notifications hide what you're quitting.
- **Settings:** reminders (it tells you if notifications are off), currency, haptics, four app icons, JSON and CSV export, erase all data, a helpline link, the privacy policy and "Rate Unhook".
- **Meet the founder** (Settings): Bruce's story, his Instagram, and his other apps Bruce Run, Bruce Speech and Pocket Court.

## Run it in Xcode

1. You need a Mac with **Xcode 16 or newer** (Xcode 26 recommended). The app supports iOS 17 and later.
2. Open `Unhook.xcodeproj`, pick an iPhone simulator, and press **⌘R**. Everything works in the Simulator, including the widgets.

**On your own iPhone:**

1. In the project's build settings, change **`UNHOOK_BUNDLE_PREFIX`** (default `com.brucegao.unhook`) to something unique, such as `com.yourname.unhook`. It sets the app, widget and test bundle IDs and the App Group in one place.
2. Select your **Team** under *Signing & Capabilities* for the **Unhook** and **UnhookWidgets** targets.
3. Plug in your iPhone and press **⌘R**.

> **Free Apple ID vs paid developer account.** Widgets read the app's data through an App Group, and free accounts (Personal Teams) can't use App Groups. Debug builds for a device therefore leave the App Group out, so the app runs fine with a free Apple ID; the widgets just show a "start your first streak" placeholder. Simulator builds and Release builds include it. `Config/README.md` has the details.

## Tests and automation

**Unit tests:** press **⌘U**. More than 200 tests (Swift Testing) cover streaks and milestones, savings and goals, slips and undo, triggers, clean days, onboarding, recovery timelines, XP, ranks and missions, data export, the coach (including crisis detection), the founder links, local prices and formatting.

**GitHub Actions** (`.github/workflows/`):

| Workflow | Runs when | What it does |
|---|---|---|
| **iOS build & test** (`ios.yml`) | Every pull request and push to `main`, or by hand | Compiles the app, widgets and tests. Checks that iOS 26-only frameworks are weak-linked, so the app can't crash at launch on iOS 17 and 18. Runs the unit tests, makes a Release device build with the runner's default Xcode, and lists the strings the compiler extracted for localization. |
| **Screenshots** (`screenshots.yml`) | A pushed commit message contains `[screenshots]` (small previews) or `[screenshots full]` (full size too), or you run it by hand | Runs `UnhookUITests/ScreenshotTests.swift` on the largest iPhone simulator with sample data, and commits the images to `AppStore/screenshots/raw/`. |
| **App Store** (`appstore.yml`) | A pushed commit message contains an `[asc …]` command, such as `[asc build]` or `[asc metadata]` | Uploads builds to TestFlight and sends the listing, screenshots, review notes, the in-app event and the submission to App Store Connect, using `tools/asc/`. |

The Screenshots and App Store workflows run on pushes to `main` and `claude/…` branches. `tools/appstore-art/` turns the raw captures into the 8 App Store screenshots, a press header and a search-result preview (Python; see its README).

## Project structure

```
Unhook.xcodeproj          Xcode project: app, widget extension, unit test and UI test targets (folders sync automatically)
Unhook/                   The app
  App/                    Entry point, tabs, AppRouter (navigation and deep links), preview and UI-test sample data
  Design/                 The Dawn design system: type, glass surfaces, the dawn orb, button styles
  Models/                 App-only logic: onboarding projection, recovery timelines, goals, triggers, achievements,
                          clean days, prices, Engagement/ (XP, ranks, missions, 30-Day Reset, tips), monetization switch
  Services/               Notifications, app lock, data export, celebrations, review prompts, widget refresh, haptics,
                          settings, Store (StoreKit 2, off in 1.0), and Coach/ (scripted and on-device coach, crisis safety)
  Intents/                Siri and Shortcuts (App Intents)
  Views/                  Onboarding, Home, Habit, AddHabit, SOS, Coach, Goals, Insights (the Progress tab), Engagement,
                          Celebration, Founder, Settings, Lock, Paywall (dormant, plus the in-app privacy policy), Components
  PrivacyInfo.xcprivacy   Privacy manifest
Shared/                   Compiled into the app and the widget: SwiftData models, model container (App Group store),
                          milestones, presets, theme colors and formatters
UnhookWidgets/            Streak and Craving SOS widgets
UnhookTests/              Unit tests (Swift Testing)
UnhookUITests/            Screenshot tests that walk through every main screen
Config/                   Entitlements (the App Group) and extra Info.plist keys
Unhook.storekit           Local StoreKit test file for Unhook Pro (unused while Pro is off)
AppStore/                 Launch kit: listing text, review notes, screenshot plan and screenshots, the in-app event,
                          privacy and launch guides, growth playbook and a roadmap
tools/                    asc/ (App Store Connect commands) and appstore-art/ (App Store screenshot art)
.github/                  The three workflows and their helper scripts
```

## Languages

The app and its App Store listing are in English. The project is set up for a String Catalog (`LOCALIZATION_PREFERS_STRING_CATALOGS`), and CI lists every string the compiler extracts, but there's no `Localizable.xcstrings` yet. Translations are planned for an update.

One part isn't English-only: the on-device coach is told to answer in the language the user writes in (`CoachPrompt.swift`). The scripted replies and the fixed crisis and emergency replies are always in English.

## Unhook Pro (switched off)

The StoreKit 2 code for **Unhook Pro** (yearly, monthly and lifetime) is still in the project, but `Monetization.isProEnabled = false` in `Unhook/Models/Monetization.swift` turns it off. While it's off, StoreKit never starts, no paywall or Pro section is shown, and every feature is unlocked. The free-plan limits (`ProLimits.freeHabits = 1`, `freeGoals = 1`) only apply when Pro is on.

The product IDs live in `Store.ProductID` and must match `Unhook.storekit` and App Store Connect: `unhook.pro.yearly` ($29.99 with a 1-week free trial), `unhook.pro.monthly` ($4.99) and `unhook.pro.lifetime` ($49.99). Turning Pro on is a separate release: see the appendix in `AppStore/README.md`.

## Launching

`AppStore/README.md` walks through the free 1.0 launch: the steps on Apple's websites and in Notion, the `[asc …]` commands in order, and the in-app event after approval. `AppStore/GROWTH_PLAYBOOK.md` covers go-to-market, and `AppStore/ROADMAP_100M.md` covers what the product needs beyond this repo (localization, iCloud sync, Apple Watch, Android and more).

---

*Unhook is a self-help tool and not a substitute for professional care. The app links to [findahelpline.com](https://findahelpline.com) for anyone who needs more support.*

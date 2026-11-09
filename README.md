# Unhook: quit anything, one day at a time

<img src="Unhook/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" align="right" alt="Unhook app icon" />

**Unhook** is an iOS app that helps people break bad habits: smoking, vaping, alcohol, doomscrolling, sugar, porn, gambling, or anything else. It counts every second you stay free, shows the money and time you win back, explains what's recovering in your body and mind, and gets you through cravings with a 60-second SOS screen and a private AI coach.

It's built with SwiftUI, SwiftData, StoreKit 2, App Intents, WidgetKit and Apple's on-device Foundation Models. There's no server and no account; everything stays on the device. The app ships in 16 languages.

---

## The growth plan, built into the product

| Stage | What the app does |
|---|---|
| **Activation** | Personalized onboarding asks what you're quitting, what it costs and why, then shows what you'll save in a year before creating your first streak. |
| **Daily habit** | Live streak counter, money saved ticking up every second, a daily pledge with a mood check-in, reminders, and Home Screen and Lock Screen widgets. |
| **Motivation** | 13 milestones with full-screen celebrations, a recovery timeline for every habit, 12 achievements, and savings goals ("New AirPods: 62% funded"). |
| **Retention** | SOS breathing for cravings, an on-device AI coach, trigger logging with insights ("cravings peak around 9 PM"), and a kind slip flow that never erases progress (with Undo for slips logged by mistake). |
| **Word of mouth** | Shareable progress cards at every milestone, plus App Store review prompts timed to high points. |
| **Discovery** | Siri, Spotlight and Action-button shortcuts, 16 languages, and localized App Store listings and keywords. |
| **Revenue** | **Unhook Pro** (StoreKit 2): yearly with a 7-day free trial, monthly, or lifetime. Pro unlocks several habits at once, full insights, unlimited savings goals and three extra app icons. SOS, streaks and the coach are always free. |
| **Trust** | Face ID app lock (alerts and widgets hide what you're quitting when it's on), data export, an in-app privacy policy, a privacy manifest, no tracking and no account. |

## Features

- **Personalized onboarding:** habit, quit date (or "earlier"), daily cost and time, your reasons, then a one-year projection, reminders opt-in and the Pro offer. The habit is saved before the paywall, so nothing is lost.
- **Live streaks:** days, hours, minutes and seconds, with a progress ring to the next of 13 milestones (1 hour to 5 years) and milestone notifications.
- **Recovery timeline** for each habit type (smoking follows WHO and NHS milestones), worded cautiously, with a "not medical advice" note.
- **Money, time and units saved,** plus **savings goals** funded in order from what you've saved.
- **SOS craving mode:** 60 seconds of guided breathing with your own reasons, then "what set it off?" and "how strong was it?", distraction ideas, and a celebration.
- **AI Craving Coach:** Apple's on-device model on iOS 26 devices with Apple Intelligence, and a scripted coach on every other iPhone. Crisis messages in any of the 16 languages get a fixed, caring reply and a helpline link.
- **Craving and trigger insights:** top triggers, peak time of day, toughest weekday, and charts.
- **Daily pledge** with a mood check-in and streak, **achievements**, and a **kind slip flow** that banks earlier clean time, with **Undo** for slips logged by mistake.
- **Widgets:** Streak (small, medium, and Lock Screen circular, rectangular and inline) and Craving SOS (opens breathing in one tap).
- **Siri and Shortcuts:** "Open SOS in Unhook", "I beat a craving in Unhook", "Check my streak in Unhook".
- **Unhook Pro** with a review-compliant paywall (trial and renewal terms, restore, Terms of Use and Privacy Policy), Ask to Buy support, and `Unhook.storekit` for local testing.
- **Settings:** reminders (it tells you if notifications are off), currency, haptics, app icon picker, Face ID lock, JSON/CSV export, erase all data, a helpline link and "rate Unhook".
- **Localized** into English, Spanish, Portuguese (Brazil), French, German, Italian, Dutch, Russian, Turkish, Arabic (right-to-left), Hindi, Indonesian, Japanese, Korean, and Chinese (Simplified and Traditional). Preset costs adapt to the local currency.

## Run it in Xcode

1. You need a Mac with **Xcode 16 or newer** (Xcode 26 recommended). The app supports iOS 17 and later.
2. Open `Unhook.xcodeproj`, pick an iPhone simulator, and press **⌘R**. Everything works in the Simulator, including widgets and test purchases.

**On your own iPhone:**

1. In the project's build settings, change **`UNHOOK_BUNDLE_PREFIX`** (default `com.brucegao.unhook`) to something unique, such as `com.yourname.unhook`. It sets the app, widget and test bundle IDs and the App Group in one place.
2. Select your **Team** under *Signing & Capabilities* for the **Unhook** and **UnhookWidgets** targets.
3. Plug in your iPhone and press **⌘R**.

> **Free Apple ID vs paid developer account.** Widgets read the app's data through an App Group, and free accounts (Personal Teams) can't use App Groups. Debug builds for a device therefore leave the App Group out, so the app runs fine with a free Apple ID; the widgets just show a "start your first streak" placeholder. Simulator builds and Release builds include it. To publish on the App Store you need the paid Apple Developer Program anyway. `Config/README.md` has the details.

**Test purchases:** the shared scheme uses `Unhook.storekit`, so the paywall shows real-looking plans in the Simulator, and you can buy, restore and expire them from Xcode's *Debug → StoreKit → Manage Transactions*.

**Tests:** press **⌘U**. Nearly 200 unit tests use Swift Testing and cover streak and savings maths, slips and undo, milestones and celebrations, goals, triggers, onboarding, the paywall copy, data export, the coach (including crisis detection in every language), local prices and formatting.

**CI:** `.github/workflows/ios.yml` runs on every pull request on a macOS runner. It finds an Xcode with an iPhone simulator, compiles the app, widget and tests, checks that iOS 26-only frameworks are weak-linked (so the app can't crash at launch on iOS 17 and 18), runs the tests, builds a Release device build with Xcode 16, and prints the localizable strings the compiler extracted.

## Project structure

```
Unhook.xcodeproj          Xcode project: app, widget extension and test targets (folders sync automatically)
Unhook/                   The app
  App/                    Entry point, root/tab navigation, AppRouter (navigation state), preview data
  Models/                 App-only logic: onboarding projection, recovery timeline, goals, triggers, achievements,
                          prices, presets for the form, monetization (Pro limits, paywall reasons, app icons)
  Services/               Store (StoreKit 2), notifications, app lock, data export, celebrations, review prompts,
                          widget refresh, haptics, settings keys, and Coach/ (scripted + on-device AI coach)
  Intents/                Siri and Shortcuts (App Intents)
  Views/                  Onboarding, Home, Habit, AddHabit, SOS, Coach, Goals, Insights, Celebration, Paywall,
                          Settings, Lock, Components
  Localizable.xcstrings   Translations (InfoPlist.xcstrings localizes the Face ID prompt)
Shared/                   Compiled into the app and the widget: SwiftData models, model container (App Group store),
                          milestones, presets, theme and formatters
UnhookWidgets/            Streak and Craving SOS widgets
UnhookTests/              Unit tests (Swift Testing)
Config/                   Entitlements and extra Info.plist keys
Unhook.storekit           Local StoreKit configuration (products match App Store Connect)
AppStore/                 Launch kit: localized metadata, screenshot plan, review notes, privacy policy,
                          growth playbook, and a roadmap to 100M users
```

## Monetization settings

`Unhook/Models/Monetization.swift` holds the free-tier limits (`ProLimits.freeHabits = 1`, `freeGoals = 1`). Product IDs live in `Store.ProductID` and must match App Store Connect and `Unhook.storekit`: `unhook.pro.yearly` ($29.99 with a 1-week free trial), `unhook.pro.monthly` ($4.99) and `unhook.pro.lifetime` ($49.99).

## Launching

`AppStore/README.md` walks through publishing: the developer account, bundle ID, App Store Connect record, in-app purchases, privacy answers, screenshots, TestFlight, metadata upload with fastlane, and submission. `AppStore/GROWTH_PLAYBOOK.md` covers go-to-market, and `AppStore/ROADMAP_100M.md` covers what the product needs beyond this repo (Android, iCloud sync, Apple Watch, community and accountability features).

---

*Unhook is a self-help tool and not a substitute for professional care. The app links to [findahelpline.com](https://findahelpline.com) for anyone who needs more support.*

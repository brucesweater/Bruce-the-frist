# Unhook App Store launch kit

This folder has what you need to put Unhook 1.0 on the App Store: the listing text, the review notes, the screenshot plan, the in-app event and this guide. Version 1.0 is free, with no in-app purchases, so the launch path below is free-only.

Most of the work is automated. You put a command such as `[asc metadata]` in a commit message, push it, and GitHub Actions does the work in App Store Connect. A few steps can only be done on Apple's websites and in Notion; they come first.

Everything in this folder is text and images, so it never affects the app build.

## What's in the kit

| File | What it's for |
|---|---|
| [`metadata/`](metadata) | The App Store listing (English (U.S.)) and the notes for App Review. Uploaded by `[asc metadata]` and `[asc review-details]`. |
| [`screenshots/`](screenshots) | `raw/`: screens captured by CI. `final/en-US/APP_IPHONE_67/`: where the 8 finished screenshots go for `[asc screenshots]` (step 8 below). |
| [`event/`](event) | The "New Year Reset 2027" in-app event: `event.json`, plus the card (1920 × 1080) and details (1080 × 1920) images. |
| [`SCREENSHOTS.md`](SCREENSHOTS.md) | The 8 screenshots, the size rules, and how the set is made. |
| [`APP_REVIEW_NOTES.md`](APP_REVIEW_NOTES.md) | How the review notes work, the App Privacy answer ("Data Not Collected") and the age rating answers. |
| [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) | Where the published privacy policy lives and how to keep it in sync with the app. |
| [Feature claim check](#feature-claim-check-before-every-submission) (below) | One command per feature the listing mentions, to prove it's in the build before you submit. |
| [`GROWTH_PLAYBOOK.md`](GROWTH_PLAYBOOK.md) | Go-to-market plan. It was written for a paid launch, so its pricing and paywall sections only matter if Pro is turned on. |
| [`ROADMAP_100M.md`](ROADMAP_100M.md) | What the product needs beyond this repo, with effort estimates. |

The scripts live outside this folder: `tools/asc/` (App Store Connect commands) and `tools/appstore-art/` (screenshot art).

### `metadata/` layout

```
metadata/
  copyright.txt              The copyright line                     (not localized)
  primary_category.txt       HEALTH_AND_FITNESS
  secondary_category.txt     LIFESTYLE
  review_information/
    notes.txt                Notes for App Review                  limit 4,000 characters, but only 3,900 are sent
  en-US/
    name.txt                 "Unhook: Quit Bad Habits"             limit 30 characters
    subtitle.txt             "Stop Smoking, Vaping, Drinking"      limit 30 characters
    keywords.txt             comma-separated, no spaces            limit 100 bytes
    promotional_text.txt     can change any time without review    limit 170 characters
    description.txt                                                limit 4,000 characters
    support_url.txt          the Notion support page
    privacy_url.txt          the Notion privacy policy
```

The listing is English only for now. There's no `release_notes.txt`: version 1.0 has no "What's New", and `[asc metadata]` doesn't upload release notes anyway (see [Updates after 1.0](#updates-after-10)). There's also no `marketing_url.txt` (optional: `[asc metadata]` uploads one if you add it).

The scripts skip any file that still contains `REPLACE_ME`, so this must print nothing before an upload:

```sh
grep -rn "REPLACE_ME" AppStore/metadata
```

Keywords count bytes, not characters: `printf %s "$(cat AppStore/metadata/en-US/keywords.txt)" | wc -c`.

---

## How the automation works

`.github/workflows/appstore.yml` runs when you push a commit whose message names a command in square brackets. For example:

```sh
git commit --allow-empty -m "Upload the listing [asc metadata]"
git push
```

- It runs on pushes to `main` and to `claude/…` branches. Watch it on GitHub under **Actions → App Store**. The logs are public, so the scripts never print secrets or phone numbers.
- Only the newest commit of a push is read. A message that also contains `[skip ci]` runs nothing.
- One message can hold several commands. They run in the order you write them. The one exception is `[asc build]`: it always runs last, on a macOS runner, after the other commands finish.
- If a command fails, the log says why. An API error prints `FAILED` and the reason, and the next commands still run. A missing step (no app record yet, no version in *Prepare for Submission*, no processed build) prints a one-line message and stops the run, so the commands after it don't run. `[asc availability]` only prints "Availability not changed" and the reason. Fix the cause and push the commands that didn't finish again.
- The App Store Connect API key is the `ASC_PRIVATE_KEY` repository secret. The key ID, issuer ID and team ID are in the workflow file.

The commands (from `tools/asc/asc.py` and `tools/asc/release.py`):

| Command | What it does |
|---|---|
| `[asc check]` | Checks the API key and lists the apps, the bundle IDs, and whether Unhook's app record exists. Changes nothing. |
| `[asc register]` | Registers `com.brucegao.unhook` and `com.brucegao.unhook.widgets` and turns on App Groups for them. Safe to run again. |
| `[asc build]` | Archives with the newest Xcode 26, signs with cloud signing and uploads to TestFlight. The build number is the date and time. Until the app record exists, it only exports the build. |
| `[asc metadata]` | Name, subtitle, description, keywords, promotional text, support and privacy URLs, categories, copyright and content rights. It also sets the version to be released automatically once it's approved. |
| `[asc age-rating]` | Sends the age rating answers (`AGE_RATING` in `release.py`) and prints the rating Apple calculates. |
| `[asc review-details]` | Uploads `notes.txt`, marks sign-in as not required, and copies the review contact from Bruce Run. |
| `[asc pricing]` | Sets the price to free. |
| `[asc availability]` | Makes the app available in every country and region except mainland China, which needs an ICP filing first. |
| `[asc screenshots]` | Replaces the listing's screenshots with the files in `screenshots/final/`. Needs `[asc metadata]` first. |
| `[asc attach-build]` | Attaches the newest processed build to the version. |
| `[asc submit]` | Submits the version for App Review. It never includes the in-app event. |
| `[asc event]` | Creates or updates the in-app event from `event/` (text and both images). It stays a draft. |
| `[asc submit-event]` | Submits draft in-app events for review on their own. Use it only after 1.0 is approved. |
| `[asc status]` | Prints the version's state, the newest processed build, review submissions and the age rating. Changes nothing. |

There are a few more: `[asc app]` (prints the app record and its versions), `[asc probe]` and `[asc inspect]` (read-only checks), and `[asc create-app]` (tries to create the app record through the API; Apple normally only allows that on the website).

> **Never ship a build made with `[asc build-nogroups]`.** It leaves out the App Group, so its widgets can't read the app's data. `[asc attach-build]` picks the newest processed build, so if you ever upload one, push a normal `[asc build]` again before you attach.

---

## The launch path

### Before you start

- Unhook uses the same Apple Developer account as Bruce Run, so the membership is already in place. A free app doesn't need the Paid Applications Agreement, banking or tax forms.
- If App Store Connect shows a banner asking you to accept an updated agreement, accept it first. Uploads and submissions stop until you do.
- Your EU trader status (under the Digital Services Act) is set once for the whole account, in App Store Connect → Business. If it's missing, the app won't appear in EU countries.
- `[asc build]` builds the commit you push it with. Make sure that's the code you want to ship, and that **iOS build & test** passed on it. That workflow runs on pull requests and on `main`; for a commit on another branch, run it by hand (*Actions → iOS build & test → Run workflow*).

### Step 1. On the websites (once)

1. **Create the App Group.** On developer.apple.com, go to *Certificates, Identifiers & Profiles → Identifiers*:
   - Click **+**, choose **App Groups**, and register `group.com.brucegao.unhook` (description: "Unhook").
   - Open the App ID `com.brucegao.unhook`, tick **App Groups**, click **Configure** (or **Edit**), select `group.com.brucegao.unhook`, then save. Do the same for `com.brucegao.unhook.widgets`.
   - Without this, the build can't include the App Group and the widgets can't read the app's data. If either App ID is missing, push `[asc register]` first.
2. **Create the app record.** In App Store Connect, go to *Apps → + → New App*:

   | Field | Value |
   |---|---|
   | Platform | iOS |
   | Name | `Unhook: Quit Bad Habits`. If it's taken, pick another name of 30 characters or fewer and put it in `metadata/en-US/name.txt`. The home-screen name stays "Unhook" either way. |
   | Primary language | English (U.S.) |
   | Bundle ID | `com.brucegao.unhook` |
   | SKU | `unhook` |
   | User access | Full access |

   This also creates version 1.0, which the commands below fill in.
3. **Answer App Privacy.** In your app, open *App Privacy → Get Started*, answer **"No, we do not collect data from this app"**, save, then click **Publish**. The product page will show "Data Not Collected". The reasons are in [APP_REVIEW_NOTES.md](APP_REVIEW_NOTES.md#2-app-privacy-answers-nutrition-label).
4. **Publish the two Notion pages**, the privacy policy and the support page. In Notion: **Share → Publish → Publish**. Then open both URLs (from `metadata/en-US/privacy_url.txt` and `support_url.txt`) in a private browser window and check that they load without signing in. App Review opens them. [PRIVACY_POLICY.md](PRIVACY_POLICY.md) lists every place the URLs appear, in case one changes.

### Step 2. Upload a build and test it

5. Push **`[asc check]`**. The log should say the key works, both bundle IDs are registered, and "Unhook app record: exists".
6. Push **`[asc build]`**. It can take up to an hour. Then wait for Apple's email saying the build has finished processing, or push `[asc status]` until "Latest processed build" shows it.
7. **Test it on your iPhone with TestFlight.** In App Store Connect → TestFlight, add yourself to an internal testing group, then install the build from the TestFlight app. Check that the widgets show your real streak (that proves the App Group works), and try SOS, the coach, the Face ID lock and data export. To let friends test too, add an external group: its first build needs a short Beta App Review, usually under a day.

### Step 3. Make the screenshots

8. Only the **iPhone 6.9"** size is needed (1320 × 2868 pixels), because Unhook is iPhone-only. No iPad screenshots. [SCREENSHOTS.md](SCREENSHOTS.md) has the 8 frames and the rules.
   - Push a commit with **`[screenshots full]`** in the message (or run *Actions → Screenshots → Run workflow* with "Also commit full-resolution screenshots" ticked). CI captures the app and commits the images to `screenshots/raw/full/`. Pull them with `git pull`.
   - Compose the set with `tools/appstore-art/` (commands in [its README](../tools/appstore-art/README.md)), and copy `tools/appstore-art/out/01.png` … `08.png` to `screenshots/final/en-US/APP_IPHONE_67/`. The number sets the order.
   - Look at all 8, then commit and push them. CI uploads what's in the repository, not what's on your computer.

### Step 4. Fill in the listing, in this order

| # | Push | The log should say |
|---|---|---|
| 9 | `[asc metadata]` | Which fields it updated, the categories, and content rights. |
| 10 | `[asc age-rating]` | The calculated age rating (about 13+). |
| 11 | `[asc review-details]` | "contact copied from Bruce Run". If it says "no contact found", type the contact details on the version page. |
| 12 | `[asc pricing]` | "Price: free". |
| 13 | `[asc availability]` | How many territories the app is available in. |
| 14 | `[asc screenshots]` | "en-US APP_IPHONE_67: uploaded 8 screenshots". |

You can put all six in one commit message, in this order. For example:

```sh
git commit --allow-empty -m "Fill in the listing [asc metadata] [asc age-rating] [asc review-details] [asc pricing] [asc availability] [asc screenshots]"
git push
```

### Step 5. Attach the build and submit

15. Push **`[asc attach-build]`**. It attaches the newest processed build to version 1.0.
16. Open the version page in App Store Connect and read it top to bottom: screenshots, text, build, App Review Information and the release option.
    - `[asc metadata]` sets the release option to release automatically once the app is approved. To pick the launch day yourself, switch it to **Manually release this version** here. Do it again after any later `[asc metadata]`, which sets it back.
17. Run the [feature claim check](#feature-claim-check-before-every-submission) on the commit you built. Then follow the QUICK TEST in `metadata/review_information/notes.txt` on the TestFlight build, exactly as written.
18. Push **`[asc submit]`**. Push `[asc status]` any time to see where the review is. Most reviews take a day or two.
    - If App Review rejects the app, the reason is in App Store Connect. Fix it, upload and attach a new build if the code changed (steps 6 and 15), and resubmit from the version page.

### Step 6. After approval

19. With the automatic release option, Unhook goes live as soon as it's approved. It can take up to a day to show up in search. (If you chose manual release, click **Release This Version**.)
20. **The in-app event.** Push **`[asc event]`** to create or update "New Year Reset 2027" as a draft. (You can also do this earlier: it's never sent to review with the app.) Then push **`[asc submit-event]`** to send it for review on its own. Do this well before the publish date in `event/event.json` (December 18, 2026). The event opens the 30-Day Reset through `unhook://challenge/reset30`.
21. Put Unhook's numeric Apple ID (App Store Connect → App Information) in `FounderLinks.appStoreID` in `Unhook/Views/Founder/FounderComponents.swift`. Then "Rate Unhook" in Settings opens the review page instead of the system prompt. It ships with the next update.
22. Follow the launch timeline in [GROWTH_PLAYBOOK.md](GROWTH_PLAYBOOK.md#2-stage-plan-0--1m--100m), set up [Custom Product Pages](SCREENSHOTS.md#per-habit-sets-for-custom-product-pages), and reply to reviews in App Store Connect.

### Updates after 1.0

- Create the new version on the website first (for example 1.1, with the **+** next to *iOS App* on your app's page). The commands only edit a version that's already in *Prepare for Submission*; they don't create one.
- Change `MARKETING_VERSION` to the same number in every target, so the widget's version matches the app's. CI sets the build number.
- Write "What's New" on the version page. `[asc metadata]` doesn't upload release notes yet. Keep them warm and specific, for example "Fixed a bug where the streak could show the wrong day after a time-zone change".
- Then repeat: `[asc build]`, a TestFlight check, the listing commands for anything that changed, `[asc attach-build]`, the feature claim check and `[asc submit]`.
- You can turn on **Phased Release** on the version page, so an update reaches people over 7 days.

---

## Common rejections, and how the kit prevents them

| Guideline | Risk | Prevention |
|---|---|---|
| 2.1 | A crash, a dead link or a broken feature during review | Test the TestFlight build on a real iPhone, publish both Notion pages, and follow the QUICK TEST before submitting |
| 2.3.1, 2.3.7 | The listing describes something that isn't in the build, or uses other brands in keywords | The feature claim check below; no third-party brand names in the description or keywords (no "NoFap", "Dry January" or competitor names) |
| 1.4.1 | Health claims | The smoking timeline cites the WHO and NHS; every timeline says "not medical advice" and suggests a doctor; the copy never promises outcomes |
| 1.1, 1.2 | The AI coach says something harmful, with no way to report it | Apple's guardrails, fixed crisis and emergency replies, and "Report this reply" on every coach reply, all explained in the notes |
| 5.1.1 | Privacy policy missing or not reachable | The Notion policy is published and linked from the listing and Settings, and the in-app policy matches it |

---

## Feature claim check (before every submission)

The listing, the review notes and the screenshots name the features below. Run these from the repository root against the commit you're shipping. Each command must print at least one line, or the number shown. If one prints nothing, the feature isn't in the build: **delete every mention of it** in `metadata/en-US/description.txt`, `metadata/en-US/promotional_text.txt`, `metadata/review_information/notes.txt` and the screenshots before you submit. Rejections for missing features (Guideline 2.3.1) are common and avoidable.

```sh
# 1  widgets (description): prints the two widget names
grep -rn -e 'configurationDisplayName("Streak")' -e 'configurationDisplayName("Craving SOS")' UnhookWidgets
# 2  Siri phrases quoted in the description
grep -n -e '"Open SOS in' -e '"Check my streak in' Unhook/Intents/UnhookShortcuts.swift
# 3  Face ID lock (description, notes, privacy policy)
grep -rn "LAContext" --include='*.swift' Unhook
# 4  JSON and CSV export (description, privacy policy)
grep -n -e "func exportJSON" -e "csvHeader =" Unhook/Services/DataExporter.swift
# 5  13 milestones and 12 ranks from Midnight to Legend: prints 13, then 12, then the two rank names
#    (description, promotional text, screenshots 3 and 7)
grep -c "Milestone(seconds:" Shared/Milestone.swift
grep -c "Rank(level:" Unhook/Models/Engagement/Rank.swift
grep -n -e '"Midnight"' -e '"Legend"' Unhook/Models/Engagement/Rank.swift
# 6  three daily missions and the 30-Day Reset with its link (description, notes, screenshots 3 and 4, the event)
grep -n "missionsPerDay = 3" Unhook/Models/Engagement/DailyMissions.swift
grep -n "length = 30" Unhook/Models/Engagement/ResetChallenge.swift
grep -n 'case "challenge"' Unhook/App/RootView.swift
# 7  milestone and rank-up celebrations, and the rating prompt (description, screenshot 7, GROWTH_PLAYBOOK.md)
grep -rnE "(struct|enum|class) (MilestoneCelebrationView|CelebrationCenter|RankUpObserver|ReviewPrompter)" --include='*.swift' Unhook
# 8  "Talk to your coach" on Today and "Report this reply" (notes, screenshot 6)
grep -rn "CoachEntryCard(" --include='*.swift' Unhook/Views/Home
grep -rn 'Button("Report this reply"' --include='*.swift' Unhook/Views/Coach
# 9  four app icons: three alternates plus the main one (description)
grep -n "ALTERNATE_APPICON_NAMES" Unhook.xcodeproj/project.pbxproj
# 10 the founder page in Settings (description, notes)
grep -rn 'Text("Meet the founder")' --include='*.swift' Unhook/Views/Settings
# 11 recovery timeline sources and the alcohol warning (description, notes)
grep -n "WHO and the NHS" Unhook/Models/RecoveryTimeline.swift
grep -rn "WithdrawalCaution()" --include='*.swift' Unhook/Views
# 12 free, nothing to buy (description, promotional text, notes, privacy policy)
grep -n "isProEnabled = false" Unhook/Models/Monetization.swift
# 13 nothing leaves the phone: only fixed links, and no URLSession (description, notes, privacy policy)
grep -rnE "URLSession|https?://" --include='*.swift' Unhook Shared UnhookWidgets
```

Check 13 should list only the helpline, support and privacy pages, Apple's privacy and Terms of Use pages (the Terms link is on the dormant paywall), the founder's Instagram and website, and App Store links. Anything else needs a line in the privacy policy, and maybe new App Privacy answers.

Also open the build and walk through the QUICK TEST in `notes.txt` exactly as written. Button names change during development, and App Review follows the notes literally.

---

## Appendix: if you turn on Unhook Pro later

Unhook Pro (yearly, monthly and lifetime) is built but switched off. Turning it on is a separate release with its own review.

1. **The switch.** Set `Monetization.isProEnabled = true` in `Unhook/Models/Monetization.swift`. It's a constant, so Pro can only come on in a new build that App Review sees. Keep it that way: never turn it on from a server or a hidden setting (Guideline 2.3.1 doesn't allow hidden or dormant features).
2. **The paywall's promises.** The paywall lists "Unlimited habits", "Full craving & trigger insights", "Unlimited savings goals" and "Exclusive app icons" (`PaywallBenefit` in `Unhook/Views/Paywall/PaywallContent.swift`). In the current code only extra habits and extra savings goals need Pro; insights and app icons are free for everyone. The "Upgrade to Pro" row in Settings promises "deeper insights" too (`SettingsView.swift`). Make both match what Pro really unlocks before you ship.
3. **Agreements.** Sign the **Paid Applications Agreement** and complete the banking and tax forms (App Store Connect → Business). Products don't load, even in the sandbox, until it's active. Selling Pro probably makes you a "trader" under the EU Digital Services Act, so review your trader status there too. The **App Store Small Business Program** lowers Apple's commission from 30% to 15%.
4. **The products.** The IDs must match `Store.ProductID` in `Unhook/Services/Store.swift` and `Unhook.storekit` exactly. A product ID can never be reused, even after you delete it.

   | Product ID | Type | US price | Notes |
   |---|---|---|---|
   | `unhook.pro.yearly` | Auto-renewable, 1 year | $29.99 | Subscription group "Unhook Pro", level 1, 1-week free trial for new subscribers |
   | `unhook.pro.monthly` | Auto-renewable, 1 month | $4.99 | Same group, level 2 |
   | `unhook.pro.lifetime` | Non-consumable | $49.99 | |

   Each product needs a display name, a description, a price and a review screenshot of the paywall. Decide on Family Sharing before you turn it on: once it's on, it can't be turned off. For the first version with purchases, select the products on the version page before you submit.
5. **Testing.** The shared scheme uses `Unhook.storekit`, so purchases work in the Simulator (*Debug → StoreKit → Manage Transactions* to refund or expire them). TestFlight builds use the sandbox, and nobody is charged. Check that prices load on a real iPhone, that the trial only shows to people who can get it, that Restore Purchases works after reinstalling, and that SOS, the crisis link, streaks and the recovery timeline stay free.
6. **The words.** The privacy policy (in the app and on Notion), the description, the promotional text, the review notes, the founder page and the first onboarding screen ("Free · Private · No account needed") all say Unhook is free or has no in-app purchases. Update every one before you submit. Add a "Terms of Use:" line with Apple's standard license link (the one the paywall uses) to the description. `[asc pricing]` stays as it is: the download stays free. [APP_REVIEW_NOTES.md](APP_REVIEW_NOTES.md#appendix-if-you-turn-on-unhook-pro-later) has a Pro section for the notes and the sandbox checks.

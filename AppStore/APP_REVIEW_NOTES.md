# App Review notes, App Privacy and age rating

This page has three parts:

1. **Notes for the App Review team.** The text that's uploaded is [`metadata/review_information/notes.txt`](metadata/review_information/notes.txt), sent by `[asc review-details]`.
2. **App Privacy ("nutrition label") answers.** "Data Not Collected", answered on the website.
3. **Age rating answers** for Apple's questionnaire (the 4+ / 9+ / 13+ / 16+ / 18+ system Apple introduced in 2025), sent by `[asc age-rating]`.

Unhook 1.0 is free, with no in-app purchases, so nothing here covers purchases. If you turn on Unhook Pro later, see the [appendix](#appendix-if-you-turn-on-unhook-pro-later).

> **Check before every submission.** Run the [feature claim check](README.md#feature-claim-check-before-every-submission), then open the build you're shipping and follow the QUICK TEST in `notes.txt` word for word. Every button name and menu path in the notes must match the app (for example "Craving? Tap for SOS", "Talk to your coach" and *Settings > Meet the founder*). App Review follows the notes literally, and rejects apps whose notes or listing describe features that aren't there (Guideline 2.3.1).

---

## 1. Notes for the App Review team

The notes live in one file: [`metadata/review_information/notes.txt`](metadata/review_information/notes.txt). `[asc review-details]` uploads it to *App Review Information → Notes*. Edit that file only. This page doesn't keep a copy, so the two can't drift apart.

The notes cover:

- **FREE, NO LOGIN:** no in-app purchases, no ads, no accounts, no server.
- **QUICK TEST** (about 3 minutes): onboarding, the Today tab, SOS, the coach (with its fixed crisis and medical emergency replies), the 30-Day Reset (`unhook://challenge/reset30`), the Progress tab and *Settings > Meet the founder*.
- **AI SAFETY:** Apple's guardrails (a blocked reply is replaced by a caring one and the helpline banner), "Report this reply", and the coach's reminder that it isn't a doctor.
- **HEALTH CONTENT:** the cautious recovery timelines, the alcohol warning and the findahelpline.com link.
- **PRIVACY** and the contact email.

When you edit them:

- Stay under 3,900 characters. App Store Connect allows 4,000, but `[asc review-details]` sends only the first 3,900, so anything after that is cut. Count with `printf %s "$(cat AppStore/metadata/review_information/notes.txt)" | wc -m`.
- App Store Connect keeps every line break, so write short paragraphs and numbered steps, and don't wrap lines by hand.
- Name buttons and menus exactly as the app shows them.
- Never leave a placeholder: a file that contains `REPLACE_ME` isn't uploaded at all.

**App Review Information fields**

| Field | Value |
|---|---|
| Sign-in required | **No.** `[asc review-details]` sets this. Leave the demo account fields empty. |
| Contact name, phone and email | `[asc review-details]` copies them from Bruce Run's App Review details, without printing them in the public log. If the log says "no contact found", type them on the version page. Use a real person who can answer within a day during review. |
| Notes | `notes.txt`, uploaded by `[asc review-details]`. |
| Attachment | Optional. A 20–30 second screen recording (onboarding → Today → SOS → coach) helps if a reviewer gets stuck. The script doesn't upload attachments, so add it on the version page. |

---

## 2. App Privacy answers ("nutrition label")

Answer on the website: *App Store Connect → your app → App Privacy → Get Started*, then click **Publish**. No `[asc …]` command does this.

**Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**

The product page then shows **"Data Not Collected."** That's accurate for the code in this repository:

| Area | What the app does | Why it isn't "collected" |
|---|---|---|
| Habits, streaks, slips, cravings, triggers, notes, pledges, moods, savings goals, missions, the challenge, achievements and settings | Stored on the iPhone: SwiftData for the records, `UserDefaults` for settings and achievement dates. | Never leaves the device. Apple defines "collect" as sending data off the device in a way you or your partners can access. |
| Purchases | None at launch. `Monetization.isProEnabled` is false, so StoreKit never starts. | There's nothing to collect. |
| Coach | Apple's on-device Foundation Models where Apple Intelligence is available, otherwise replies built into the app. Conversations aren't saved. | No message or reply leaves the device. Nothing goes to you or to a third-party AI service. |
| Widgets and Siri | The widgets read the app's data from an App Group container shared only by the app and its widget extension. Siri shortcuts use the same on-device data. | The App Group is on the device. Nothing is sent. |
| Face ID | `LocalAuthentication` only tells the app pass or fail. | Biometric data never reaches the app. |
| Data export and progress cards | Make a file that the user shares through the share sheet. | The user sends it, to a place they choose. |
| "Contact support" and "Report this reply" | Open the user's mail app (a `mailto:` link) with a draft to the developer. A report includes the coach's reply. | The user decides whether to send it, from their own mail app. The app sends nothing itself. |
| Notifications | Scheduled on the device. | No push server, no device token. |
| Links (helplines, the support and privacy pages, Apple's privacy policy, the founder's Instagram, website and apps) | Open outside the app. | The app sends nothing. Those sites have their own policies. |
| Crash reports | Only Apple's opt-in crash and energy reports (Xcode Organizer). | Collected by Apple from users who opt in to share with developers. No SDK. |

**The privacy manifests agree with this.** `Unhook/PrivacyInfo.xcprivacy` and `UnhookWidgets/PrivacyInfo.xcprivacy` both say `NSPrivacyTracking = false`, with no tracking domains and no collected data types. Both declare why they use `UserDefaults`: the app gives `CA92.1` (its own settings) and `1C8F.1` (the App Group it shares with the widgets), and the widget extension gives `1C8F.1`. App Store Connect emails a warning after upload if a required reason is missing.

**When this label stops being true.** Update the label, the privacy manifests and the privacy policy ([PRIVACY_POLICY.md](PRIVACY_POLICY.md)) *before* you ship any of these:

- An analytics or attribution SDK, even a privacy-first one ([GROWTH_PLAYBOOK.md](GROWTH_PLAYBOOK.md) explains the trade-off).
- A crash reporter other than Apple's (Sentry, Crashlytics and similar).
- iCloud sync **through your own server**. CloudKit in the user's *private* database doesn't count as collection, because you can't read it.
- Accounts, community, accountability buddies or anything with a backend ([ROADMAP_100M.md](ROADMAP_100M.md)).
- A cloud AI model for the coach. That would also need the user's explicit consent before any personal data goes to a third-party AI (Guideline 5.1.2).

Keep the in-app copy honest at the same time. Settings currently says *"No account, no tracking, no ads. Unhook never sends your habits anywhere."* That must stay true.

**Privacy Policy URL** is still required with "Data Not Collected". Unhook's is the Notion page in `metadata/en-US/privacy_url.txt`, which `[asc metadata]` uploads. [PRIVACY_POLICY.md](PRIVACY_POLICY.md) explains how it's kept in step with the in-app policy.

---

## 3. Age rating answers

`[asc age-rating]` sends the answers in `AGE_RATING` in `tools/asc/release.py` and prints the rating Apple calculates. The table explains them. If you change an answer, change it in `release.py` too, or the next `[asc age-rating]` puts the old one back.

Unhook talks about smoking, vaping, alcohol, cannabis, porn and gambling **only as habits to quit**. Apple's guidance asks for the content as it really appears, so "references to quitting" still count as references.

| Question area | Answer | Reason |
|---|---|---|
| Parental controls, age assurance | No | None in the app. |
| Unrestricted web access | No | The app only opens fixed links, outside the app: the helpline directory, Unhook's support and privacy pages, Apple's privacy policy, and the founder's Instagram, website and apps. There's no in-app browser. |
| User-generated content, social media, messaging and chat | No | Notes and reasons stay on the device. Change this if community features or accountability buddies ship. |
| Advertising | No | No ads. |
| Alcohol, tobacco or drug use or references | **Infrequent / Mild** | Preset names, reasons and recovery steps refer to quitting these substances. |
| Mature or suggestive themes | **Infrequent / Mild** | The "Porn" preset: its name, suggested reasons and recovery timeline, none of them explicit. No sexual imagery. |
| Sexual content or nudity, graphic sexual content | None | None. |
| Gambling (real money), simulated gambling, contests, loot boxes | No / None | "Gambling" is only a habit to quit. There are no gambling mechanics. |
| Medical or treatment information | **Infrequent / Mild** | General recovery information with a "not medical advice" note. |
| Health or wellness topics | **Yes** | Habit change and cravings. |
| Violence, weapons, horror, profanity, crude humor | None | None. |
| AI assistant or chatbot | Not in the script | If the questionnaire on the website asks, answer **Yes**: the on-device coach writes text. It's told to stay supportive and non-clinical. |

**Expected outcome:** about **13+**. Under the old system, infrequent references to alcohol, tobacco or drugs and mild mature themes mapped to 12+, which became 13+. Your actual rating is whatever App Store Connect calculates.

**Overriding to a higher rating.** On the website, App Store Connect lets you choose a higher rating than the calculated one. Think about it before launch:

- **Stay at 13+** if you want to reach teens who vape. That's a large group trying to quit, and a public-health positive.
- **Choose 16+ or 18+** if you want less review friction around the porn preset, or if you plan paid campaigns limited to adults anyway.
- Ratings can differ by region. Some US states and other countries are adding age-assurance rules, and Apple provides the Declared Age Range API for apps that need it. Check whether any of these apply before each major release.

**Marketing stays 18+.** Whatever the store rating, aim paid ads and creator campaigns at adults (18+, or the local drinking or smoking age where it's higher). Never show nicotine products, alcohol or gambling in a positive light in creatives.

---

## Appendix: if you turn on Unhook Pro later

Skip this for 1.0. It only applies after `Monetization.isProEnabled` is set to true (the steps are in the [launch guide's appendix](README.md#appendix-if-you-turn-on-unhook-pro-later)).

**Notes.** Change "FREE, NO LOGIN" in `notes.txt`, and add a section like this. Check every path against the build first:

```text
UNHOOK PRO (In-App Purchases, submitted with this version)
- unhook.pro.yearly: auto-renewable, 1 year, 1-week free trial for eligible new subscribers
- unhook.pro.monthly: auto-renewable, 1 month
- unhook.pro.lifetime: non-consumable, one-time purchase
Both subscriptions are in the "Unhook Pro" subscription group. The paywall is the last onboarding screen (close it with the X to continue on the free plan). It also opens from Settings > Upgrade to Pro, and when you add a second habit or a second savings goal. Restore purchases, Terms of Use and Privacy Policy are on the paywall. SOS, streaks and the crisis link are always free.
```

**App Privacy.** Purchases through StoreKit alone don't change "Data Not Collected": Apple processes the payment, and the app only gets signed transactions on the device. The privacy policy does change, because it says there are no in-app purchases.

**What App Review needs.** It tests purchases in the sandbox by itself, but:

1. The **Paid Applications Agreement** must be active, with banking and tax forms complete. Until it is, the paywall shows no prices, which is a common rejection.
2. All three products must be **Ready to Submit**, each with a display name, a description, a price and a review screenshot of the paywall.
3. For the first version with purchases, select the products on the version page before you submit. New products are only reviewed together with a build.

**Test it yourself:**

| Where | How |
|---|---|
| Simulator / Xcode | The shared scheme uses `Unhook.storekit` at the repository root, so purchases work with no account. Use *Debug → StoreKit → Manage Transactions* to refund, expire or renew. |
| TestFlight | TestFlight builds use the sandbox. Testers are never charged, and subscriptions renew on a fast schedule. |
| A sandbox account | Create one in *App Store Connect → Users and Access → Sandbox*. On the iPhone, sign in under *Settings → Developer → Sandbox Apple Account*. Use a fresh account to see the free trial again: the introductory offer is once per subscription group. |

Before submitting, check that:

- [ ] Prices load on the paywall on a real iPhone with a sandbox account, not only in the Simulator.
- [ ] Buying yearly shows the 7-day free trial in Apple's purchase sheet, and an account that already used the trial sees no trial wording (the paywall checks `isEligibleForIntroOffer`).
- [ ] Restore Purchases works after deleting and reinstalling the app.
- [ ] A refund in *Manage Transactions* removes Pro (the store listens to `Transaction.updates`).
- [ ] The paywall shows the price, the billing period, what the trial turns into, and links to the Terms of Use and Privacy Policy (Guideline 3.1.2).
- [ ] SOS, the crisis link, streaks, milestones and the recovery timeline all work without Pro.
- [ ] Every Pro benefit the paywall names is really Pro-only in that build.

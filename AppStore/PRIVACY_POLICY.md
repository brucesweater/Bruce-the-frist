# Privacy policy

Unhook's privacy policy is a Notion page. It still has to be published before release ([see below](#before-release-publish-it)):

**https://onyx-payment-888.notion.site/Unhook-Privacy-Policy-413b68ad1a0f818bb77dd8f06dfb3919**

This file doesn't hold a copy of the policy. It says where the policy is used, and how to keep it right when the app changes.

## Where the URL is used

| Place | Where it comes from |
|---|---|
| App Store Connect → App Information → *Privacy Policy URL* | `metadata/en-US/privacy_url.txt`, uploaded by `[asc metadata]` |
| The "Privacy:" line at the end of the App Store description | `metadata/en-US/description.txt` |
| Settings → Privacy & security → **Privacy Policy website**, and "Read this policy on the web" at the end of the in-app policy | `FounderLinks.privacyPolicy` in `Unhook/Views/Founder/FounderComponents.swift` |

If the URL ever changes, update all three.

The support page works the same way: `metadata/en-US/support_url.txt`, the "Support:" line of the description, and `FounderLinks.supportPage` (Settings → Support → **Support website**).

## Before release: publish it

The page exists in Notion, but it still has to be published. In Notion, open it and choose **Share → Publish → Publish**. Do the same for the support page. Then open both URLs in a private browser window and check that they load without signing in. App Review opens these links, and a policy that doesn't load can get the app rejected (Guideline 5.1.1).

## Keep it the same as the in-app policy

Settings → Privacy & security → **Privacy Policy** opens the same policy inside the app. Its text is in `Unhook/Views/Paywall/PrivacyPolicyView.swift`, and the Notion page says the same thing. Keep the two in sync:

- Change both at the same time, with the same words.
- Update the effective date in both. In the app it's `effectiveDate` in `PrivacyPolicyView.swift` (currently November 9, 2026).
- Use the same contact email in both. The app uses `FounderLinks.emailAddress`.

## When features change

The policy describes what the app does today. Before you ship a change like the ones below, update the in-app policy and the Notion page together, and check the App Privacy answers in [APP_REVIEW_NOTES.md](APP_REVIEW_NOTES.md#2-app-privacy-answers-nutrition-label).

| If you… | Change this part of the policy | Also update |
|---|---|---|
| Turn on Unhook Pro | "The short version" and "What Unhook does not do" both say there are no in-app purchases. | The description, promotional text, review notes, founder page and first onboarding screen ("Free · Private · No account needed"), which say Unhook is free |
| Store a new kind of data | "What stays on your device" lists everything the app keeps. | Make sure **Erase all data** deletes it too |
| Add analytics, ads, a crash reporter or any third-party SDK | "The short version" and "What Unhook does not do" | App Privacy answers and both `PrivacyInfo.xcprivacy` files |
| Add a server, accounts, sync or community features | Most of the policy: it says Unhook has no server and nothing you enter leaves the iPhone. | App Privacy answers, the privacy manifests, and the "Your data stays on your device" row in Settings |
| Send coach messages to a cloud AI | "The craving coach" | App Privacy answers. Ask for the user's consent first (Guideline 5.1.2). |
| Use the camera, microphone, photos, contacts, location or health data | "What Unhook does not do" says the app has no access to any of these. | App Privacy answers |
| Add or change a link that leaves the app | "Links" | |
| Change how widgets, Siri, notifications, the app lock or sharing work | The matching section: "Widgets and Siri", "Notifications", "Face ID and passcode lock" or "Sharing and exporting" | |

This isn't legal advice. If you add accounts, analytics or a backend, have the policy reviewed: laws such as GDPR, UK GDPR, CCPA/CPRA and US state health-data laws (for example Washington's My Health My Data Act) can apply.

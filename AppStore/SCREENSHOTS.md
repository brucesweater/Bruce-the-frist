# Screenshot plan

Most people decide from the first three screenshots in search results, often without opening the product page. So every frame leads with a **benefit headline** (what the user gets), and the real in-app screen is the proof underneath it.

## Sizes required (checked November 2026)

Unhook is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so only the iPhone slot is needed.

| Slot in App Store Connect | Accepted portrait sizes (px) | Required? |
|---|---|---|
| **iPhone 6.9"** (`APP_IPHONE_67` in the API) | 1320 × 2868, 1290 × 2796 | Yes. App Store Connect scales it down for smaller iPhones. |

Rules for every slot: 1–10 screenshots per language (Unhook uses **8**); PNG or JPEG with no alpha channel; the UI must be the real app (Guideline 2.3.3). Device frames and captions are fine; no fake reviews, "#1" claims or prices.

## How the set is made

1. **Capture.** Push a commit whose message contains `[screenshots full]`. CI runs `UnhookUITests/ScreenshotTests.swift` on the iPhone 17 Pro Max simulator with the status bar at 9:41, in English, with sample data from `UITestSupport` (a 47-day smoking streak, 12 days off doomscrolling, 5 days off sugar, two savings goals, 30 pledges, 26 beaten cravings, day 5 of the 30-Day Reset). It commits the screens to `AppStore/screenshots/raw/full/` (and small previews to `raw/preview/`).
2. **Compose.** `tools/appstore-art/compose.py` paints one wide night-to-sunrise sky across the set, frames each screen in an iPhone, adds the headlines, gold orbits, a laurel badge and line icons, and puts Unhook on Bruce's phone for frame 1. See [tools/appstore-art/README.md](../tools/appstore-art/README.md).
3. **Upload.** The finished frames go in `AppStore/screenshots/final/en-US/APP_IPHONE_67/` (`01.jpg` … `08.jpg`; the number sets the order). `[asc screenshots]` uploads them.

## The 8 frames

The first three carry the conversion. In order they answer: *What is it? Why will it work for me? Will I keep at it?*

| # | Headline | Sub-caption | Screen |
|---|---|---|---|
| 1 | **QUIT ANYTHING. ONE DAY AT A TIME.** | Hi, I'm Bruce. I made Unhook to help you. | Bruce holding his phone, showing Today (the "47 DAYS FREE" orb) |
| 2 | **BEAT ANY CRAVING.** | 60 seconds of guided breathing. Laurel: NO ADS · NO ACCOUNT · NO TRACKING | SOS breathing with the user's own reason |
| 3 | **LEVEL UP EVERY DAY.** | Daily missions, XP and 12 ranks. | Progress: rank card, this week, clean-days calendar |
| 4 | **THE 30-DAY RESET.** | One small step a day. | The 30-Day Reset on day 5 |
| 5 | **WATCH YOUR BODY HEAL.** | A recovery timeline for every habit. | Habit detail: recovery timeline |
| 6 | **PRIVATE BY DESIGN.** | A coach on your iPhone. No account, no tracking. | The coach |
| 7 | **CELEBRATE EVERY WIN.** | Milestones from your first hour to five years. | Milestone celebration |
| 8 | **SAVE FOR WHAT MATTERS.** | Turn the money you save into real goals. | Savings goals |

Keep the captions true to the app: every claim above is checked against the code before each release (see APP_REVIEW_NOTES.md). Don't caption the coach "AI" without saying it needs Apple Intelligence, and don't use "free" or prices in captions (Guideline 2.3.7 covers pricing words in metadata).

## Variants worth testing

Run these with **Product Page Optimization** in App Store Connect (up to 3 treatments against the original, split by percentage of traffic). Results reach confidence faster on high-traffic storefronts, so test in the US first.

1. **Frame 1 headline**: "Quit anything. One day at a time." vs. a money-first "See what quitting gives back" over the onboarding one-year projection. Don't put a promised amount ("You'll save $1,000") or a made-up testimonial ("Like Sam…") in a screenshot: both read as claims you can't back up (Guideline 2.3.1, and the FTC treats invented testimonials as deceptive).
2. **Order**: SOS first (frames 3, 1, 2…) vs. the streak first. People who search "craving" may convert better on SOS.
3. **Icon**: the alternate icons (Midnight, Sunrise, Forest) are already in the binary, which is what PPO icon tests need.

## Per-habit sets for Custom Product Pages

Build one Custom Product Page per big habit, each with its own first three frames, and assign keywords from the keyword field to it (see [GROWTH_PLAYBOOK.md](GROWTH_PLAYBOOK.md)). Keywords can only be assigned from your **latest approved** version, so this starts after the first release is approved:

| Page | Frame 1 headline | Keywords to assign (from `keywords.txt`) |
|---|---|---|
| Vaping | "Quit vaping. Breathe easier." | nicotine |
| Drinking | "Your sober counter, done kindly" | sober, sobriety, alcohol |
| Porn | "Take back your focus" (keep visuals neutral, no suggestive imagery) | porn |
| Screen time | "Put the phone down. Get your time back." (don't claim to "reset" dopamine, which is a physiological claim) | dopamine, detox, screen, time |
| Gambling | "Protect your money. Rebuild trust." | gambling |
| Sugar | "Cut back on sugar, one day at a time" | sugar |

Apple recommends a unique set of keywords for each page, so give each keyword to one page only. Only words from the keyword field are offered for assignment, so words in the app name or subtitle (quit, smoking, vaping, drinking…) keep pointing at the default page. Check *App Store Connect Help → Custom product pages* for the current rules before you set this up.

# Admit Compass

College admission chance calculator: a React 19 + TypeScript + Vite 8 web app that estimates a student's chance of
admission at any of 3,510 U.S. colleges and helps balance a college list. User-facing docs are in `README.md`.

## Commands

Node 22.12 or newer.

- `npm install`: install dependencies
- `npm run dev`: dev server at http://localhost:5173 (`npm run dev -- --host` to open it from a phone on the same Wi-Fi)
- `npm test`: Vitest unit tests (`src/**/*.test.ts`); keep them green
- `npm run build`: type-check (`tsconfig.json` for `src`, `tsconfig.node.json` for `scripts`) and build to `dist/`
- `npm run build:single`: one self-contained HTML file in `dist-single/` (preview sharing)
- `npm run calibrate`: print estimates for sample students; run after changing model parameters
- `npm run build:data -- <folder>`: regenerate `src/data/colleges.json` from unzipped IPEDS CSVs (HD, IC, ADM, DRVEF)

## Layout

- `src/model/`: admission model (`admission.ts`, every tunable number in `PARAMS`), list outlook (`list.ts`),
  rating scales and tiers (`scales.ts`), SAT/ACT concordance, stats helpers. Pure functions with tests.
- `src/data/`: `colleges.json` (generated, do not hand-edit), `colleges.ts` (decodes its compact rows; the row layout
  is documented there and in `scripts/build-colleges.ts`), `curated.ts` (hand-checked overrides for 147 colleges,
  keyed by IPEDS unit ID; use `idForSlug('mit')` in code), `search.ts` (ranked search), `states.ts`.
- `src/components/`: `ProfilePanel`, `CollegeSearch` (combobox), `CollegeList` (meter list, table view, reorder
  animation), `CollegeRow` (expandable details), `charts.tsx` (chance meter, fit bars, factor bars, tier bar),
  `ListSummary`, `Dialogs` (how it works, add a college by hand), `controls.tsx` (rating bars, segmented, switch,
  number + slider).
- `src/state/store.ts`: reducer, example student, persistence in `localStorage` key `admit-compass:v1`.
- `src/styles/`: `tokens.css` (all colors as tokens, light + dark, three-state theme), `base.css`, `app.css`.
- `public/`: favicon, PWA manifest, icons, `sw.js` (offline cache; bump `CACHE` when changing caching rules).
- `scripts/`: data build, calibration, single-file fragment helper.

## How the model works

Latent-index (probit-style) model with a logistic link: the admit rate (in-state/out-of-state at publics) sets the
cutoff; GPA, SAT/ACT and rigor are placed against the admitted class's middle 50% and mapped into the applicant pool
with truncated-normal moments; activities, essays and recommendations explain part of the non-academic score; hooks
and early rounds shift it. A shared uncertainty term `tau` gives the 80% likely range and links outcomes across the
list. Tiers are capped by admit rate (under 15% admitted is never above "reach"). Open-admission colleges short-circuit
to a 99% estimate.

## Design rules

- Palette: ink blue (`--accent`) for interaction, estimates and factors that help; red pen (`--pen`, `--viz-hurt`) for
  what hurts; highlighter yellow (`--highlight`, `--highlight-mark`) always means "you". Use tokens, never raw colors.
- Chance tiers use one blue ramp (`--tier-1`…`--tier-5`), light to dark as chances rise, flipped in dark mode. It was
  checked for contrast and color-blind separation; re-check if you change it.
- Fonts are self-hosted in `src/fonts/` (Geist for UI and figures, Geist Mono for data, Bricolage Grotesque for
  headings).
- Keep phone width working (no horizontal scroll), keyboard access, and `prefers-reduced-motion`.
- Copy is plain and direct, written from the student's side.

## Data notes

- IPEDS (U.S. Department of Education, public domain): newest admissions file used is fall 2023 (`ADM2023`), with
  the 2024–25 directory (`HD2024`). Download from https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx.
- Curated values (GPA, current test policy, early rounds, legacy, residency rates) are approximate; GPA for
  non-curated colleges is estimated by a regression the build script fits on the curated set.

## Status and next steps

- PR https://github.com/brucesweater/Bruce-the-frist/pull/8 (branch `brucehandsomegao/intelligent-davinci-q1btlx`)
  holds all of this. Turn on GitHub Pages (Settings → Pages → Source: GitHub Actions), then merge; the site deploys to
  https://brucesweater.github.io/Bruce-the-frist/ and can be added to a phone home screen.
- Ideas: native iOS build with Capacitor (needs Xcode on the Mac); intended-major selectivity; editing a listed
  college's numbers; sharing or exporting a list; side-by-side compare; refreshing data when NCES publishes `ADM2024`.

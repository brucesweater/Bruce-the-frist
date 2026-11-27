/**
 * Admission chance model.
 *
 * The model is a latent-index (probit) model of how selective admissions work:
 *
 *   1. Every applicant has a hidden admission score T ~ N(0, 1) within the
 *      college's applicant pool. The college admits everyone above a cutoff,
 *      so the cutoff is set by the admit rate: cut = Φ⁻¹(1 − rate).
 *   2. T mixes academics (X) and everything else (H):
 *        T = ρ·X + √(1 − ρ²)·H
 *      ρ is higher at less selective colleges, where grades and scores decide
 *      most cases, and lower at highly selective ones, where nearly every
 *      applicant has strong grades.
 *   3. Published ranges describe the *admitted* class, so we place the student
 *      against that class (z-scores for GPA and test scores) and convert to the
 *      applicant pool with the moments of a truncated normal.
 *   4. Self-reported ratings (activities, essays, recommendations) explain part
 *      of H; the rest stays uncertain. Hooks and early rounds shift T.
 *   5. A shared model-uncertainty term τ widens the estimate into a likely range
 *      and links outcomes across a list (see list.ts).
 *
 * Every tunable number lives in PARAMS so the behaviour is easy to inspect.
 */
import { actToSat, satToAct } from './concordance';
import { ACTIVITIES, ESSAYS, RECOMMENDATIONS, RIGOR, ROUND_LABELS, TIERS, tierInfo } from './scales';
import { clamp, expectNormal, interpIndex, logistic, logit, normCdf, normInv, normPdf } from './stats';
import type {
  College,
  Estimate,
  Factor,
  GpaFit,
  Latent,
  Note,
  Plan,
  Profile,
  Round,
  TestFit,
  TierId,
} from './types';

export const PARAMS = {
  /** Correlation between academics and the admission score: 0.5 at ≤4% admitted, 0.75 at ≥35%. */
  rhoSelective: 0.5,
  rhoBroad: 0.75,
  /** Share of the non-academic score that self-reported ratings explain. */
  knownShareSelective: 0.5,
  knownShareBroad: 0.4,
  /** Academic composite: GPA and test weights, and the composite's spread. */
  gpaWeight: 0.55,
  testWeight: 0.45,
  compositeSd: 0.81,
  /** With no test score, the expected composite given GPA alone. */
  gpaOnlyScale: 0.85,
  /** Test-optional applicants without scores (admitted-class SD units, at the most selective colleges). */
  withheldPenalty: 0.25,
  /** Course rigor: shift per level below / above what the college expects. */
  rigorStepBelow: 0.25,
  rigorStepAbove: 0.18,
  /** Non-academic ratings on the known-holistic scale (index = rating level). */
  activities: [-1.2, -0.5, 0.15, 0.85, 1.75],
  essays: [-0.6, 0, 0.45, 1.0],
  recs: [-0.45, 0, 0.5],
  holisticWeights: { activities: 0.62, essays: 0.25, recs: 0.18 },
  /** Shifts in applicant-pool SD units (scaled down at less selective colleges). */
  rounds: { RD: 0, EA: 0.08, REA: 0.18, ED: 0.28, ED2: 0.22 } as Record<Round, number>,
  legacy: 0.45,
  athleteBase: 1.6,
  athleteSelective: 0.6,
  firstGen: 0.15,
  international: 0.15,
  /** Log-odds shifts used when a public university's residency rates are unknown. */
  inStateShift: 0.35,
  outStateShift: -0.3,
  /** Model uncertainty (applicant-pool SD units). */
  tau: 0.25,
  tauNoTest: 0.08,
  tauCustom: 0.05,
  /** Nothing is ever certain: estimates stay inside [floor, ceiling]. */
  floor: 0.002,
  ceiling: 0.99,
  /** Selective colleges are never called safeties, however strong the profile. */
  tierCaps: [
    { below: 0.15, max: 'reach' },
    { below: 0.25, max: 'target' },
    { below: 0.45, max: 'likely' },
  ] as ReadonlyArray<{ below: number; max: TierId }>,
};

const P = PARAMS;
/** z-value for the 10th / 90th percentile. */
const Z80 = 1.2815516;

/** 1 for the most selective colleges (≤10% admitted), 0 for broad-access ones (≥60%). */
export const selectivity = (rate: number): number => clamp((0.6 - rate) / 0.5, 0, 1);

export const rhoFor = (rate: number): number =>
  P.rhoSelective + (P.rhoBroad - P.rhoSelective) * clamp((rate - 0.04) / 0.31, 0, 1);

const knownShareFor = (rate: number): number =>
  P.knownShareBroad + (P.knownShareSelective - P.knownShareBroad) * selectivity(rate);

/** Estimated spread of unweighted GPAs among admitted students, given their average. */
export const gpaSpread = (avg: number): number => clamp(0.12 + 0.75 * (4 - avg), 0.14, 0.5);

/**
 * The unknown part of an application is given a logistic rather than normal
 * shape. Its fatter tails reflect that admissions always hold surprises (an
 * unusual talent, an institutional need), so long shots are never quite zero.
 */
const LOGISTIC_SCALE = 1.702;
const link = (z: number): number => logistic(LOGISTIC_SCALE * z);

export function baseRateFor(
  college: College,
  residence: string,
): { rate: number; label: Estimate['baseRateLabel'] } {
  if (college.control !== 'public' || !residence) return { rate: college.rate, label: 'overall' };
  if (residence === college.state) {
    const rate = college.inState ?? logistic(logit(college.rate) + P.inStateShift);
    return { rate, label: 'in-state' };
  }
  const rate = college.outState ?? logistic(logit(college.rate) + P.outStateShift);
  return { rate, label: 'out-of-state' };
}

function rigorShift(level: number, rate: number): number {
  const expected = 2 + 2 * selectivity(rate); // "Demanding" … "Most demanding"
  const diff = level - expected;
  return diff < 0 ? diff * P.rigorStepBelow : diff * P.rigorStepAbove;
}

/** Rounds a student can pick at this college (all of them when the college's rounds aren't known). */
export const roundsFor = (college: College): readonly Round[] =>
  college.rounds ? ['RD', ...college.rounds] : ['RD', 'EA', 'REA', 'ED', 'ED2'];

/** Legacy status counts when the college says so; if unknown, assume private colleges consider it. */
export const considersLegacy = (college: College): boolean => college.legacy ?? college.control !== 'public';

function roundShift(round: Round, college: College, sel: number): number {
  if (!roundsFor(college).includes(round)) return 0;
  return P.rounds[round] * (0.5 + 0.5 * sel);
}

interface TestInfo {
  mode: Estimate['testMode'];
  z: number | null;
  fit: TestFit | null;
}

function testInfo(profile: Profile, college: College): TestInfo {
  if (college.test === 'blind') return { mode: 'blind', z: null, fit: null };
  const score =
    profile.testType === 'sat' ? profile.sat : profile.testType === 'act' ? profile.act : null;
  if (score == null) {
    return { mode: college.test === 'required' ? 'missing-required' : 'test-optional', z: null, fit: null };
  }
  let kind: TestFit['kind'];
  let you: number;
  let range: readonly [number, number];
  let converted = false;
  if (profile.testType === 'sat') {
    if (college.sat) {
      kind = 'SAT';
      you = score;
      range = college.sat;
    } else if (college.act) {
      kind = 'ACT';
      you = satToAct(score);
      range = college.act;
      converted = true;
    } else return { mode: 'no-data', z: null, fit: null };
  } else if (college.act) {
    kind = 'ACT';
    you = score;
    range = college.act;
  } else if (college.sat) {
    kind = 'SAT';
    you = actToSat(score);
    range = college.sat;
    converted = true;
  } else return { mode: 'no-data', z: null, fit: null };

  const mid = (range[0] + range[1]) / 2;
  const sd = Math.max((range[1] - range[0]) / 1.349, kind === 'SAT' ? 40 : 1.2);
  const z = clamp((you - mid) / sd, -3.5, 2.5);
  return {
    mode: 'submitted',
    z,
    fit: {
      kind,
      you: kind === 'SAT' ? Math.round(you / 10) * 10 : Math.round(you),
      p25: range[0],
      p75: range[1],
      percentile: normCdf(z),
      converted,
    },
  };
}

function gpaInfo(gpa: number, college: College): { z: number; fit: GpaFit } {
  const sd = gpaSpread(college.gpa);
  const z = clamp((gpa - college.gpa) / sd, -3.5, 2);
  return {
    z,
    fit: {
      you: gpa,
      avg: college.gpa,
      low: Math.max(0, college.gpa - 0.674 * sd),
      high: Math.min(4, college.gpa + 0.674 * sd),
      percentile: normCdf(z),
    },
  };
}

/** Everything the evaluation needs, already reduced to model units. */
interface Components {
  rate: number;
  zGpa: number;
  zTest: number | null;
  /** Test-optional applicant applying without scores. */
  withheld: boolean;
  rigor: number;
  ec: number;
  es: number;
  rec: number;
  round: number;
  legacy: number;
  athlete: number;
  firstGen: number;
  intl: number;
  tau: number;
}

const squash = (p: number): number => P.floor + (P.ceiling - P.floor) * p;

/** Probability of admission at a given value of the shared uncertainty term. */
export const chanceAt = (latent: Latent, z: number): number =>
  squash(link((latent.mu + latent.tau * z - latent.cut) / latent.sigma));

function evaluate(c: Components): { chance: number; low: number; high: number; latent: Latent } {
  const r = clamp(c.rate, 0.005, 0.995);
  const sel = selectivity(r);
  const cut = normInv(1 - r);
  const rho = rhoFor(r);
  // Moments of academic strength among admitted students (truncated normal).
  const lambda = normPdf(cut) / r;
  const admitMean = rho * lambda;
  const admitSd = Math.sqrt(Math.max(0.05, 1 - rho * rho * lambda * (lambda - cut)));

  let zAdmit =
    c.zTest !== null
      ? (P.gpaWeight * c.zGpa + P.testWeight * c.zTest) / P.compositeSd
      : P.gpaOnlyScale * c.zGpa;
  if (c.withheld) zAdmit -= P.withheldPenalty * (0.4 + 0.6 * sel);
  zAdmit = clamp(zAdmit + c.rigor, -3.5, 2.5);
  const academic = admitMean + admitSd * zAdmit; // position in the applicant pool

  const a = knownShareFor(r);
  const rest = Math.sqrt(1 - rho * rho);
  const W = P.holisticWeights;
  const known = W.activities * c.ec + W.essays * c.es + W.recs * c.rec;
  const hooks = c.round + c.legacy + c.athlete + c.firstGen - c.intl;

  const mu = rho * academic + rest * a * known + hooks;
  const sigma = rest * Math.sqrt(1 - a * a);
  const latent: Latent = { mu, sigma, cut, tau: c.tau };

  const chance = expectNormal((z) => chanceAt(latent, z));
  const low = chanceAt(latent, -Z80);
  const high = chanceAt(latent, Z80);
  return { chance, low: Math.min(low, chance), high: Math.max(high, chance), latent };
}

export function tierFor(chance: number, baseRate: number): { tier: TierId; cap: TierId | null } {
  let tier: TierId = TIERS[0].id;
  for (const t of TIERS) if (chance >= t.min) tier = t.id;
  for (const cap of P.tierCaps) {
    if (baseRate < cap.below) {
      if (tierInfo(tier).rank > tierInfo(cap.max).rank) return { tier: cap.max, cap: cap.max };
      break;
    }
  }
  return { tier, cap: null };
}

/** Open-admission colleges admit every applicant with a diploma or equivalent. */
function openAdmissionEstimate(college: College): Estimate {
  const certain: Latent = { mu: 10, sigma: 1, cut: 0, tau: 0 };
  return {
    collegeId: college.id,
    chance: P.ceiling,
    low: P.ceiling,
    high: P.ceiling,
    tier: 'safety',
    tierCap: null,
    baseRate: 1,
    baseRateLabel: 'overall',
    factors: [],
    notes: [
      {
        kind: 'info',
        text: `${displayName(college)} has open admission: anyone with a high school diploma or equivalent is admitted. Some programs, such as nursing, can have their own requirements.`,
      },
    ],
    testFit: null,
    gpaFit: null,
    testMode: 'no-data',
    latent: certain,
  };
}

const pct = (p: number): string => (p < 0.01 ? 'under 1%' : `${Math.round(p * 100)}%`);
const fmtGpa = (g: number): string => g.toFixed(2);
export const displayName = (c: College): string => c.short ?? c.name;

/**
 * Estimate a student's chance of admission at one college.
 * Returns null until the profile has a GPA.
 */
export function estimateChance(profile: Profile, college: College, plan: Plan): Estimate | null {
  if (profile.gpa == null || !Number.isFinite(profile.gpa)) return null;
  if (college.openAdmission) return openAdmissionEstimate(college);
  const gpaValue = clamp(profile.gpa, 0, 4);
  const base = baseRateFor(college, profile.residence);
  const sel = selectivity(base.rate);
  const gpa = gpaInfo(gpaValue, college);
  const test = testInfo(profile, college);

  const ecReference = interpIndex(P.activities, 1 + sel); // what a typical applicant here brings
  const zTest = test.mode === 'submitted' ? test.z : null;
  const comp: Components = {
    rate: base.rate,
    zGpa: gpa.z,
    zTest,
    withheld: test.mode === 'test-optional',
    rigor: rigorShift(profile.rigor, base.rate),
    ec: P.activities[profile.activities] - ecReference,
    es: P.essays[profile.essays],
    rec: P.recs[profile.recs],
    round: roundShift(plan.round, college, sel),
    legacy: plan.legacy && considersLegacy(college) ? P.legacy * (0.4 + 0.6 * sel) : 0,
    athlete: plan.athlete ? P.athleteBase + P.athleteSelective * sel : 0,
    firstGen: profile.firstGen ? P.firstGen * (0.5 + 0.5 * sel) : 0,
    intl: profile.residence === 'INTL' ? P.international * (0.5 + 0.5 * sel) : 0,
    // Less is known when scores would count but are missing. Test-blind colleges
    // don't use scores, so nothing is lost there.
    tau: P.tau + (zTest === null && test.mode !== 'blind' ? P.tauNoTest : 0) + (college.custom ? P.tauCustom : 0),
  };
  const result = evaluate(comp);
  const name = displayName(college);

  // Factor breakdown: how much each part moves the estimate versus a typical profile.
  const factors: Factor[] = [];
  const add = (id: string, label: string, detail: string, alt: Partial<Components>) => {
    factors.push({ id, label, detail, delta: result.chance - evaluate({ ...comp, ...alt }).chance });
  };
  add('gpa', 'GPA', `${fmtGpa(gpaValue)} vs. ${fmtGpa(college.gpa)} average`, { zGpa: 0 });
  if (test.mode === 'submitted' && test.fit) {
    const f = test.fit;
    add('test', f.converted ? `${profile.testType.toUpperCase()} (as ${f.kind})` : f.kind, `${f.you} vs. ${f.p25}–${f.p75} middle 50%`, { zTest: 0 });
  } else if (test.mode === 'test-optional') {
    add('test', 'No test scores', 'Applying test-optional', { withheld: false, zTest: 0, tau: comp.tau - P.tauNoTest });
  }
  add('rigor', 'Course rigor', RIGOR[profile.rigor].label, { rigor: 0 });
  add('activities', 'Activities and awards', ACTIVITIES[profile.activities].label, { ec: 0 });
  add('essays', 'Essays', ESSAYS[profile.essays].label, { es: 0 });
  add('recs', 'Recommendations', RECOMMENDATIONS[profile.recs].label, { rec: 0 });
  if (comp.round) add('round', 'Application round', ROUND_LABELS[plan.round].long, { round: 0 });
  if (base.label !== 'overall') {
    add(
      'residency',
      base.label === 'in-state' ? 'In-state applicant' : 'Out-of-state applicant',
      `${pct(base.rate)} ${base.label} admit rate vs. ${pct(college.rate)} overall`,
      { rate: college.rate },
    );
  }
  if (comp.legacy) add('legacy', 'Legacy', 'A parent graduated from here', { legacy: 0 });
  if (comp.athlete) add('athlete', 'Recruited athlete', 'Supported by a coach', { athlete: 0 });
  if (comp.firstGen) add('firstGen', 'First-generation', 'First in your family to attend college', { firstGen: 0 });
  if (comp.intl) add('intl', 'International applicant', 'Applying from outside the U.S.', { intl: 0 });
  factors.sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));

  const { tier, cap } = tierFor(result.chance, base.rate);

  // Notes: warnings first, then tips, then context.
  const notes: Note[] = [];
  if (test.mode === 'missing-required') {
    notes.push({
      kind: 'warning',
      text: `${name} requires SAT or ACT scores. This estimate assumes your scores will be in line with your GPA.`,
    });
  }
  if (test.mode === 'no-data') {
    notes.push({ kind: 'info', text: `There is no test score range for ${name}, so scores were left out of this estimate.` });
  }
  if (test.mode === 'submitted' && college.test === 'optional') {
    const withheld = evaluate({ ...comp, zTest: null, withheld: true, tau: comp.tau + P.tauNoTest }).chance;
    if (withheld - result.chance >= 0.01) {
      notes.push({
        kind: 'tip',
        text: `Your score is below the middle of ${name}'s range. Applying test-optional could raise your estimate to about ${pct(withheld)}.`,
      });
    }
  }
  if (plan.round === 'RD' && college.rounds?.includes('ED')) {
    const ed = evaluate({ ...comp, round: roundShift('ED', college, sel) }).chance;
    if (ed - result.chance >= 0.03) {
      notes.push({
        kind: 'tip',
        text: `Applying Early Decision could raise this to about ${pct(ed)}. ED is binding, so save it for your first choice.`,
      });
    }
  }
  if (plan.athlete) {
    notes.push({
      kind: 'info',
      text: 'Recruited athletes are admitted at much higher rates, but only with a coach’s support. Ask the coach where you stand.',
    });
  }
  if (test.mode === 'blind') {
    notes.push({ kind: 'info', text: `${name} does not consider SAT or ACT scores, so this estimate uses your GPA and coursework.` });
  }
  if (cap) {
    const rateText = pct(base.rate);
    notes.push({
      kind: 'info',
      text:
        cap === 'reach'
          ? `Only ${rateText} of applicants are admitted, so ${name} is a reach for everyone, however strong the profile.`
          : `With ${rateText} of applicants admitted, we don’t label ${name} higher than “${tierInfo(cap).label}”.`,
    });
  }

  return {
    collegeId: college.id,
    chance: result.chance,
    low: result.low,
    high: result.high,
    tier,
    tierCap: cap,
    baseRate: base.rate,
    baseRateLabel: base.label,
    factors,
    notes,
    testFit: test.fit,
    gpaFit: gpa.fit,
    testMode: test.mode,
    latent: result.latent,
  };
}

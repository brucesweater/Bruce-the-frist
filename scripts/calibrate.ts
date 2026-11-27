// Prints estimated chances for a few archetypal students across a spread of
// colleges, so changes to the model's parameters can be sanity-checked.
// Run with: npm run calibrate
import { COLLEGE_BY_ID } from '../src/data/colleges';
import { idForSlug } from '../src/data/curated';
import { estimateChance } from '../src/model/admission';
import { listOutlook } from '../src/model/list';
import type { Plan, Profile } from '../src/model/types';

const base: Profile = {
  gpa: 3.85, testType: 'sat', sat: 1450, act: null, rigor: 3, activities: 2, essays: 1, recs: 1,
  residence: 'OH', firstGen: false,
};

const students: Record<string, Partial<Profile>> = {
  'Top (4.0/1580, national)': { gpa: 4.0, sat: 1580, rigor: 4, activities: 4, essays: 3, recs: 2 },
  'Strong (3.95/1520, regional)': { gpa: 3.95, sat: 1520, rigor: 4, activities: 3, essays: 2, recs: 1 },
  'Good (3.85/1450, leader)': {},
  'Solid (3.6/1300, involved)': { gpa: 3.6, sat: 1300, rigor: 2, activities: 1, essays: 1, recs: 1 },
  'Average (3.3/1150)': { gpa: 3.3, sat: 1150, rigor: 1, activities: 1, essays: 1, recs: 0 },
  'No test (3.9, leader)': { gpa: 3.9, testType: 'none', sat: null, rigor: 3, activities: 2, essays: 2, recs: 1 },
};

const ids = ['harvard', 'mit', 'upenn', 'columbia', 'williams', 'umich', 'ucla', 'northeastern', 'bu', 'uw-madison', 'uiuc', 'osu', 'purdue', 'asu'];

const pct = (p: number) => `${(p * 100).toFixed(p < 0.1 ? 1 : 0)}%`.padStart(6);

console.log('College'.padEnd(14), ...Object.keys(students).map((s) => s.slice(0, 22).padEnd(24)));
for (const slug of ids) {
  const id = idForSlug(slug);
  const college = COLLEGE_BY_ID.get(id)!;
  const cells = Object.values(students).map((overrides) => {
    const profile = { ...base, ...overrides };
    const plan: Plan = { collegeId: id, round: 'RD', legacy: false, athlete: false };
    const e = estimateChance(profile, college, plan)!;
    return `${pct(e.chance)} (${pct(e.low).trim()}–${pct(e.high).trim()}) ${e.tier.slice(0, 6)}`.padEnd(24);
  });
  console.log(`${college.short ?? college.name}`.slice(0, 13).padEnd(14), ...cells);
}

// Hooks and rounds at a highly selective college.
console.log('\nPenn, "Good" student:');
const penn = COLLEGE_BY_ID.get(idForSlug('upenn'))!;
for (const [label, plan] of [
  ['RD', { round: 'RD', legacy: false, athlete: false }],
  ['ED', { round: 'ED', legacy: false, athlete: false }],
  ['ED + legacy', { round: 'ED', legacy: true, athlete: false }],
  ['Recruited athlete', { round: 'RD', legacy: false, athlete: true }],
] as const) {
  const e = estimateChance(base, penn, { collegeId: penn.id, ...plan })!;
  console.log(`  ${label.padEnd(18)} ${pct(e.chance)}`);
}

console.log('\nResidency, "Good" student at Michigan / UNC:');
for (const id of ['umich', 'unc'].map(idForSlug)) {
  for (const residence of [COLLEGE_BY_ID.get(id)!.state, 'OH', '']) {
    const e = estimateChance({ ...base, residence }, COLLEGE_BY_ID.get(id)!, { collegeId: id, round: 'RD', legacy: false, athlete: false })!;
    console.log(`  ${COLLEGE_BY_ID.get(id)!.short!.padEnd(9)} residence=${(residence || 'unset').padEnd(5)} ${pct(e.chance)} (${e.baseRateLabel} ${pct(e.baseRate).trim()})`);
  }
}

// A sample list.
const listIds = ['stanford', 'umich', 'uiuc', 'uw-madison', 'osu', 'purdue', 'asu'];
const plans: Plan[] = listIds.map((slug) => ({ collegeId: idForSlug(slug), round: 'RD', legacy: false, athlete: false }));
const estimates = plans.map((p) => estimateChance(base, COLLEGE_BY_ID.get(p.collegeId)!, p)!);
const outlook = listOutlook(estimates, plans, COLLEGE_BY_ID);
const independent = 1 - estimates.reduce((s, e) => s * (1 - e.chance), 1);
console.log('\nSample list:', listIds.join(', '));
console.log(`  expected ${outlook.expected.toFixed(2)}, ≥1 ${pct(outlook.atLeastOne)} (${pct(outlook.atLeastOneLow).trim()}–${pct(outlook.atLeastOneHigh).trim()}), independent ${pct(independent)}`);
console.log('  tiers', outlook.tiers);
console.log('  advice', outlook.advice.map((a) => a.text));

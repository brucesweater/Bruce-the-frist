import { chanceAt, displayName } from './admission';
import { NORMAL_NODES } from './stats';
import type { College, Estimate, Note, Plan, TierId } from './types';

export interface ListOutlook {
  count: number;
  /** Expected number of acceptances (sum of chances). */
  expected: number;
  /** Chance of at least one acceptance, and its likely range. */
  atLeastOne: number;
  atLeastOneLow: number;
  atLeastOneHigh: number;
  tiers: Record<TierId, number>;
  advice: Note[];
}

/**
 * Outcomes across a list are linked: if an application is stronger (or weaker)
 * than the model assumes, that holds at every college. Conditioning on the
 * shared uncertainty term makes the colleges independent, so
 *   P(at least one) = E_Z[ 1 − Π (1 − p_i(Z)) ].
 * This is more cautious than multiplying the odds as if they were independent.
 */
export function atLeastOneAt(estimates: readonly Estimate[], z: number): number {
  let none = 1;
  for (const e of estimates) none *= 1 - chanceAt(e.latent, z);
  return 1 - none;
}

export function listOutlook(
  estimates: readonly Estimate[],
  plans: readonly Plan[],
  colleges: ReadonlyMap<string, College>,
): ListOutlook {
  const tiers: Record<TierId, number> = { 'long-shot': 0, reach: 0, target: 0, likely: 0, safety: 0 };
  for (const e of estimates) tiers[e.tier]++;
  const count = estimates.length;
  const expected = estimates.reduce((s, e) => s + e.chance, 0);

  let atLeastOne = 0;
  for (const n of NORMAL_NODES) atLeastOne += n.w * atLeastOneAt(estimates, n.z);
  const atLeastOneLow = count ? atLeastOneAt(estimates, -1.2815516) : 0;
  const atLeastOneHigh = count ? atLeastOneAt(estimates, 1.2815516) : 0;

  return {
    count,
    expected,
    atLeastOne: count ? atLeastOne : 0,
    atLeastOneLow: Math.min(atLeastOneLow, atLeastOne),
    atLeastOneHigh: Math.max(atLeastOneHigh, atLeastOne),
    tiers,
    advice: adviceFor(count, tiers, count ? atLeastOne : 0, plans, colleges),
  };
}

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;
const nameOf = (plan: Plan, colleges: ReadonlyMap<string, College>) => {
  const c = colleges.get(plan.collegeId);
  return c ? displayName(c) : 'this college';
};

function adviceFor(
  count: number,
  tiers: Record<TierId, number>,
  atLeastOne: number,
  plans: readonly Plan[],
  colleges: ReadonlyMap<string, College>,
): Note[] {
  const advice: Note[] = [];
  if (count === 0) return advice;

  const ed = plans.filter((p) => p.round === 'ED');
  const ed2 = plans.filter((p) => p.round === 'ED2');
  const rea = plans.filter((p) => p.round === 'REA');
  if (ed.length > 1) {
    advice.push({
      kind: 'warning',
      text: `You picked Early Decision at ${ed.length} colleges. ED is binding, so you can apply ED to only one at a time.`,
    });
  }
  if (ed2.length > 1) {
    advice.push({
      kind: 'warning',
      text: `You picked Early Decision II at ${ed2.length} colleges. Like ED, it is binding, so choose one.`,
    });
  }
  if (rea.length > 1 || (rea.length === 1 && ed.length > 0)) {
    advice.push({
      kind: 'warning',
      text: `Restrictive Early Action at ${nameOf(rea[0], colleges)} usually rules out early applications to other private colleges. Check its rules before you apply.`,
    });
  }

  const safetyNet = tiers.likely + tiers.safety;
  const reaches = tiers['long-shot'] + tiers.reach;
  if (safetyNet === 0) {
    advice.push({
      kind: 'warning',
      text: 'Add at least two colleges where you are likely to be admitted. Right now none of your colleges is a likely or a safety.',
    });
  } else if (safetyNet === 1 && count >= 3) {
    advice.push({ kind: 'tip', text: 'Add one more likely or safety college so you have a backup for your backup.' });
  }
  if (atLeastOne < 0.9 && safetyNet > 0) {
    advice.push({
      kind: 'warning',
      text: `Your chance of at least one acceptance is about ${Math.round(atLeastOne * 100)}%. Likely and safety colleges raise it fastest.`,
    });
  }
  if (reaches === 0 && count >= 4) {
    advice.push({ kind: 'tip', text: 'There are no reaches on your list. If you have a dream school, you have room to add it.' });
  }
  if (tiers['long-shot'] >= 4 && tiers['long-shot'] / count > 0.5) {
    advice.push({
      kind: 'tip',
      text: 'More than half of your list is long shots. Swapping a few for targets gives you better odds of real choices in the spring.',
    });
  }
  if (advice.length === 0) {
    advice.push({
      kind: 'info',
      text: `Your list is balanced: ${plural(reaches, 'reach', 'reaches')}, ${plural(tiers.target, 'target', 'targets')} and ${plural(safetyNet, 'likely or safety college', 'likely or safety colleges')}.`,
    });
  }
  return advice;
}

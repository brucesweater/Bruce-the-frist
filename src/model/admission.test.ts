import { describe, expect, it } from 'vitest';
import { COLLEGE_BY_ID } from '../data/colleges';
import { idForSlug } from '../data/curated';
import { baseRateFor, estimateChance, roundsFor, tierFor } from './admission';
import { listOutlook } from './list';
import type { College, Estimate, Plan, Profile } from './types';

const college = (slug: string): College => COLLEGE_BY_ID.get(idForSlug(slug))!;
const plan = (c: College, extra: Partial<Plan> = {}): Plan => ({ collegeId: c.id, round: 'RD', legacy: false, athlete: false, ...extra });

const student: Profile = {
  gpa: 3.85, testType: 'sat', sat: 1450, act: null, rigor: 3, activities: 2, essays: 1, recs: 1,
  residence: 'OH', firstGen: false,
};

const chance = (c: College, p: Partial<Profile> = {}, pl: Partial<Plan> = {}): Estimate =>
  estimateChance({ ...student, ...p }, c, plan(c, pl))!;

describe('estimateChance', () => {
  const harvard = college('harvard');
  const michigan = college('umich');
  const osu = college('osu');

  it('needs a GPA', () => {
    expect(estimateChance({ ...student, gpa: null }, harvard, plan(harvard))).toBeNull();
  });

  it('keeps every estimate a probability with an ordered range', () => {
    for (const c of [harvard, michigan, osu, college('ucla'), college('asu')]) {
      for (const gpa of [2.5, 3.3, 3.9, 4]) {
        const e = chance(c, { gpa });
        expect(e.chance).toBeGreaterThan(0);
        expect(e.chance).toBeLessThan(1);
        expect(e.low).toBeLessThanOrEqual(e.chance);
        expect(e.high).toBeGreaterThanOrEqual(e.chance);
      }
    }
  });

  it('rises with GPA, test scores and the rest of the application', () => {
    const levels = <K extends keyof Profile>(key: K, values: Profile[K][]) => values.map((v) => chance(michigan, { [key]: v }).chance);
    const increasing = (xs: number[]) => xs.every((x, i) => i === 0 || x > xs[i - 1]);
    expect(increasing(levels('gpa', [3.2, 3.5, 3.8, 4]))).toBe(true);
    expect(increasing(levels('sat', [1200, 1350, 1450, 1550]))).toBe(true);
    expect(increasing(levels('rigor', [0, 1, 2, 3, 4]))).toBe(true);
    expect(increasing(levels('activities', [0, 1, 2, 3, 4]))).toBe(true);
    expect(increasing(levels('essays', [0, 1, 2, 3]))).toBe(true);
    expect(increasing(levels('recs', [0, 1, 2]))).toBe(true);
  });

  it('treats SAT and concordant ACT scores alike', () => {
    const sat = chance(michigan, { testType: 'sat', sat: 1460 }).chance;
    const act = chance(michigan, { testType: 'act', act: 33, sat: null }).chance;
    expect(Math.abs(sat - act)).toBeLessThan(0.03);
  });

  it('gives a median admitted student better odds than the admit rate at selective colleges', () => {
    const e = chance(michigan, { gpa: michigan.gpa, sat: (michigan.sat![0] + michigan.sat![1]) / 2, rigor: 4 });
    expect(e.chance).toBeGreaterThan(e.baseRate);
  });

  it('uses residency at public universities', () => {
    expect(baseRateFor(michigan, 'MI')).toEqual({ rate: michigan.inState, label: 'in-state' });
    expect(baseRateFor(michigan, 'OH').label).toBe('out-of-state');
    expect(baseRateFor(harvard, 'MA').label).toBe('overall');
    expect(chance(michigan, { residence: 'MI' }).chance).toBeGreaterThan(chance(michigan, { residence: 'OH' }).chance);
  });

  it('rewards early decision and hooks', () => {
    const penn = college('upenn');
    const rd = chance(penn).chance;
    expect(chance(penn, {}, { round: 'ED' }).chance).toBeGreaterThan(rd);
    expect(chance(penn, {}, { legacy: true }).chance).toBeGreaterThan(rd);
    expect(chance(penn, {}, { athlete: true }).chance).toBeGreaterThan(0.5);
    expect(chance(penn, { firstGen: true }).chance).toBeGreaterThan(rd);
  });

  it('ignores rounds a college does not offer and legacy where it is not considered', () => {
    expect(roundsFor(harvard)).toEqual(['RD', 'REA']);
    expect(chance(harvard, {}, { round: 'ED' }).chance).toBeCloseTo(chance(harvard).chance, 10);
    const mit = college('mit');
    expect(chance(mit, {}, { legacy: true }).chance).toBeCloseTo(chance(mit).chance, 10);
  });

  it('ignores test scores at test-blind colleges', () => {
    const ucla = college('ucla');
    const e = chance(ucla, { sat: 1600 });
    expect(e.testMode).toBe('blind');
    expect(e.chance).toBeCloseTo(chance(ucla, { sat: 1000 }).chance, 10);
    expect(e.factors.some((f) => f.id === 'test')).toBe(false);
  });

  it('flags missing scores where they are required', () => {
    const e = chance(harvard, { testType: 'none', sat: null });
    expect(e.testMode).toBe('missing-required');
    expect(e.notes[0].kind).toBe('warning');
  });

  it('suggests applying test-optional when a score is low', () => {
    const e = chance(michigan, { sat: 1200 });
    expect(e.notes.some((n) => n.kind === 'tip' && n.text.includes('test-optional'))).toBe(true);
  });

  it('never calls a highly selective college more than a reach', () => {
    const e = chance(harvard, { gpa: 4, sat: 1600, rigor: 4, activities: 4, essays: 3, recs: 2 }, { legacy: true });
    expect(e.chance).toBeGreaterThan(0.4);
    expect(e.tier).toBe('reach');
    expect(e.tierCap).toBe('reach');
  });

  it('treats open admission as a sure thing', () => {
    const open = [...COLLEGE_BY_ID.values()].find((c) => c.openAdmission)!;
    const e = estimateChance({ ...student, gpa: 2.1 }, open, plan(open))!;
    expect(e.tier).toBe('safety');
    expect(e.chance).toBeGreaterThan(0.98);
  });

  it('explains the estimate with factors sorted by impact', () => {
    const e = chance(michigan, { gpa: 3.4, activities: 4 });
    const sizes = e.factors.map((f) => Math.abs(f.delta));
    expect(sizes).toEqual([...sizes].sort((a, b) => b - a));
    expect(e.factors.find((f) => f.id === 'gpa')!.delta).toBeLessThan(0);
    expect(e.factors.find((f) => f.id === 'activities')!.delta).toBeGreaterThan(0);
  });
});

describe('tierFor', () => {
  it('maps chances to tiers', () => {
    expect(tierFor(0.05, 0.6).tier).toBe('long-shot');
    expect(tierFor(0.3, 0.6).tier).toBe('reach');
    expect(tierFor(0.5, 0.6).tier).toBe('target');
    expect(tierFor(0.7, 0.6).tier).toBe('likely');
    expect(tierFor(0.9, 0.6).tier).toBe('safety');
  });

  it('caps tiers at selective colleges', () => {
    expect(tierFor(0.9, 0.1)).toEqual({ tier: 'reach', cap: 'reach' });
    expect(tierFor(0.9, 0.2)).toEqual({ tier: 'target', cap: 'target' });
    expect(tierFor(0.9, 0.4)).toEqual({ tier: 'likely', cap: 'likely' });
    expect(tierFor(0.3, 0.1)).toEqual({ tier: 'reach', cap: null });
  });
});

describe('listOutlook', () => {
  const slugs = ['stanford', 'umich', 'uiuc', 'osu', 'asu'];
  const plans = slugs.map((s) => plan(college(s)));
  const estimates = plans.map((p) => estimateChance(student, COLLEGE_BY_ID.get(p.collegeId)!, p)!);
  const outlook = listOutlook(estimates, plans, COLLEGE_BY_ID);

  it('adds up expected acceptances', () => {
    expect(outlook.expected).toBeCloseTo(estimates.reduce((s, e) => s + e.chance, 0), 10);
    expect(outlook.count).toBe(5);
    expect(Object.values(outlook.tiers).reduce((a, b) => a + b, 0)).toBe(5);
  });

  it('accounts for linked outcomes when combining odds', () => {
    const independent = 1 - estimates.reduce((s, e) => s * (1 - e.chance), 1);
    expect(outlook.atLeastOne).toBeLessThanOrEqual(independent + 1e-9);
    expect(outlook.atLeastOne).toBeGreaterThanOrEqual(Math.max(...estimates.map((e) => e.chance)) - 1e-9);
    expect(outlook.atLeastOneLow).toBeLessThanOrEqual(outlook.atLeastOne);
    expect(outlook.atLeastOneHigh).toBeGreaterThanOrEqual(outlook.atLeastOne);
  });

  it('warns about more than one binding early decision', () => {
    const edPlans = plans.map((p, i) => (i < 2 ? { ...p, round: 'ED' as const } : p));
    const advice = listOutlook(estimates, edPlans, COLLEGE_BY_ID).advice;
    expect(advice.some((a) => a.kind === 'warning' && a.text.includes('Early Decision'))).toBe(true);
  });

  it('asks for safer colleges when a list is all reaches', () => {
    const reachPlans = ['harvard', 'stanford', 'mit'].map((s) => plan(college(s)));
    const reachEstimates = reachPlans.map((p) => estimateChance(student, COLLEGE_BY_ID.get(p.collegeId)!, p)!);
    const advice = listOutlook(reachEstimates, reachPlans, COLLEGE_BY_ID).advice;
    expect(advice[0].kind).toBe('warning');
  });

  it('handles an empty list', () => {
    const empty = listOutlook([], [], COLLEGE_BY_ID);
    expect(empty.atLeastOne).toBe(0);
    expect(empty.advice).toEqual([]);
  });
});

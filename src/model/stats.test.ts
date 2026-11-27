import { describe, expect, it } from 'vitest';
import { actToSat, roundedActFor, roundedSatFor, satToAct } from './concordance';
import { expectNormal, interpIndex, NORMAL_NODES, normCdf, normInv } from './stats';

describe('normal distribution helpers', () => {
  it('matches known values of Φ', () => {
    expect(normCdf(0)).toBeCloseTo(0.5, 6);
    expect(normCdf(1.959964)).toBeCloseTo(0.975, 5);
    expect(normCdf(-1)).toBeCloseTo(0.158655, 5);
  });

  it('inverts Φ', () => {
    for (const p of [0.001, 0.025, 0.2, 0.5, 0.8, 0.975, 0.999]) {
      expect(normCdf(normInv(p))).toBeCloseTo(p, 6);
    }
  });

  it('integrates against the normal density', () => {
    expect(NORMAL_NODES.reduce((s, n) => s + n.w, 0)).toBeCloseTo(1, 10);
    expect(expectNormal((z) => z)).toBeCloseTo(0, 10);
    expect(expectNormal((z) => z * z)).toBeCloseTo(1, 4);
    expect(expectNormal((z) => normCdf(z))).toBeCloseTo(0.5, 6);
  });

  it('interpolates fractional positions', () => {
    expect(interpIndex([0, 10, 20], 0.5)).toBe(5);
    expect(interpIndex([0, 10, 20], 5)).toBe(20);
    expect(interpIndex([0, 10, 20], -1)).toBe(0);
  });
});

describe('SAT/ACT concordance', () => {
  it('follows the official table', () => {
    expect(actToSat(36)).toBe(1590);
    expect(actToSat(33)).toBe(1460);
    expect(actToSat(24)).toBe(1180);
    expect(roundedActFor(1460)).toBe(33);
    expect(roundedActFor(1600)).toBe(36);
    expect(roundedSatFor(30)).toBe(1370);
  });

  it('is monotonic and round-trips', () => {
    let prev = 0;
    for (let act = 9; act <= 36; act += 0.5) {
      const sat = actToSat(act);
      expect(sat).toBeGreaterThan(prev);
      expect(satToAct(sat)).toBeCloseTo(act, 6);
      prev = sat;
    }
  });
});

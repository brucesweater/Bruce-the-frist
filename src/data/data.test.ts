import { describe, expect, it } from 'vitest';
import { COLLEGE_BY_ID, COLLEGES, DATA_META } from './colleges';
import { CURATED, idForSlug } from './curated';
import { searchColleges } from './search';
import { STATE_NAME } from './states';

const TERRITORIES = new Set(['PR', 'GU', 'VI', 'AS', 'MP']);

describe('college dataset', () => {
  it('covers thousands of U.S. colleges with unique IDs', () => {
    expect(COLLEGES.length).toBeGreaterThan(3000);
    expect(COLLEGE_BY_ID.size).toBe(COLLEGES.length);
    expect(DATA_META.count).toBe(COLLEGES.length);
  });

  it('has valid fields for every college', () => {
    for (const c of COLLEGES) {
      expect(c.name.length).toBeGreaterThan(2);
      expect(STATE_NAME.has(c.state) || TERRITORIES.has(c.state)).toBe(true);
      expect(c.rate).toBeGreaterThan(0);
      expect(c.rate).toBeLessThanOrEqual(1);
      expect(c.gpa).toBeGreaterThanOrEqual(2.5);
      expect(c.gpa).toBeLessThanOrEqual(4);
      if (c.sat) {
        expect(c.sat[0]).toBeGreaterThanOrEqual(400);
        expect(c.sat[1]).toBeLessThanOrEqual(1600);
        expect(c.sat[0]).toBeLessThan(c.sat[1]);
      }
      if (c.act) {
        expect(c.act[0]).toBeGreaterThanOrEqual(1);
        expect(c.act[1]).toBeLessThanOrEqual(36);
        expect(c.act[0]).toBeLessThan(c.act[1]);
      }
      if (c.openAdmission) expect(c.rate).toBe(1);
    }
  });

  it('includes every curated college with its hand-checked details', () => {
    for (const cur of CURATED) {
      const c = COLLEGE_BY_ID.get(cur.id)!;
      expect(c, cur.slug).toBeDefined();
      expect(c.curated).toBe(true);
      expect(c.gpa).toBe(cur.gpa);
      expect(c.test).toBe(cur.test);
      expect(c.rounds).toEqual(cur.rounds);
    }
  });

  it('has residency rates that bracket the overall rate', () => {
    for (const c of COLLEGES) {
      if (c.inState === undefined || c.outState === undefined) continue;
      expect(c.rate).toBeGreaterThanOrEqual(Math.min(c.inState, c.outState) - 0.05);
      expect(c.rate).toBeLessThanOrEqual(Math.max(c.inState, c.outState) + 0.05);
    }
  });
});

describe('searchColleges', () => {
  const top = (q: string) => searchColleges(COLLEGES, q, 5).map((c) => c.id);

  it('finds colleges by common abbreviations', () => {
    expect(top('mit')[0]).toBe(idForSlug('mit'));
    expect(top('ucla')[0]).toBe(idForSlug('ucla'));
    expect(top('unc')[0]).toBe(idForSlug('unc'));
    expect(top('penn')[0]).toBe(idForSlug('upenn'));
    expect(top('Penn State')[0]).toBe(idForSlug('psu'));
  });

  it('finds colleges by name, ignoring case and punctuation', () => {
    expect(top('harvard')[0]).toBe(idForSlug('harvard'));
    expect(top('university of michigan')[0]).toBe(idForSlug('umich'));
    expect(top('Texas A&M')[0]).toBe(idForSlug('tamu'));
    expect(top('st. olaf').length).toBeGreaterThan(0);
    expect(COLLEGE_BY_ID.get(top('st. olaf')[0])!.name).toMatch(/Olaf/);
  });

  it('finds colleges by place', () => {
    const inOhio = searchColleges(COLLEGES, 'ohio', 20);
    expect(inOhio.length).toBe(20);
    expect(inOhio.map((c) => c.id)).toContain(idForSlug('osu'));
  });

  it('returns nothing for gibberish or empty input', () => {
    expect(top('')).toEqual([]);
    expect(top('zzqxv')).toEqual([]);
  });
});

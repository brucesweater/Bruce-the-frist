import type { College } from '../model/types';
import { STATE_NAME } from './states';

/** Lowercase, strip accents and punctuation, and unify common spellings. */
export function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/&/g, ' and ')
    .replace(/['’.]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\bsaint\b/g, 'st')
    .replace(/\bmount\b/g, 'mt')
    .trim();
}

const STOPWORDS = new Set(['of', 'the', 'at', 'and', 'in', 'for', 'de', 'la']);

interface Entry {
  college: College;
  name: string;
  nameTokens: string[];
  acronym: string;
  alts: string[];
  altTokens: string[];
  placeTokens: string[];
  boost: number;
}

const cache = new WeakMap<readonly College[], Entry[]>();

function indexFor(colleges: readonly College[]): Entry[] {
  const hit = cache.get(colleges);
  if (hit) return hit;
  const entries = colleges.map((college): Entry => {
    const name = normalize(college.name);
    const nameTokens = name.split(' ');
    const alts = [college.short, ...(college.aka?.split('|') ?? [])]
      .filter((s): s is string => Boolean(s))
      .map(normalize)
      .filter(Boolean);
    const placeTokens = [
      ...normalize(college.city).split(' '),
      college.state.toLowerCase(),
      ...normalize(STATE_NAME.get(college.state) ?? '').split(' '),
    ].filter(Boolean);
    const popularity = Math.log10(1 + Math.max(college.apps ?? 0, college.size ?? 0));
    return {
      college,
      name,
      nameTokens,
      acronym: nameTokens.filter((t) => !STOPWORDS.has(t)).map((t) => t[0]).join(''),
      alts,
      altTokens: alts.flatMap((a) => a.split(' ')),
      placeTokens,
      boost: popularity * 25 + (college.level === 4 ? 40 : 0) + (college.curated ? 30 : 0),
    };
  });
  cache.set(colleges, entries);
  return entries;
}

const matches = (tokens: readonly string[], t: string) => tokens.some((w) => w.startsWith(t));
const exact = (tokens: readonly string[], t: string) => tokens.includes(t);

/**
 * Ranked search by name, abbreviation, city or state. Every word typed must
 * match the start of a word somewhere in the college's names or location.
 */
export function searchColleges(colleges: readonly College[], query: string, limit = 8): College[] {
  const q = normalize(query);
  if (!q) return [];
  const qTokens = q.split(' ');
  const scored: Array<{ college: College; score: number }> = [];

  for (const e of indexFor(colleges)) {
    let inName = 0;
    let inAlt = 0;
    let whole = 0;
    let ok = true;
    for (const t of qTokens) {
      if (matches(e.nameTokens, t)) inName++;
      else if (matches(e.altTokens, t)) inAlt++;
      else if (!matches(e.placeTokens, t)) {
        ok = false;
        break;
      }
      if (exact(e.nameTokens, t) || exact(e.altTokens, t)) whole++;
    }
    const acronymHit = qTokens.length === 1 && q.length >= 3 && e.acronym.startsWith(q);
    if (!ok && !acronymHit) continue;

    let score = e.boost + whole * 15;
    if (e.alts.includes(q)) score += 1000;
    else if (acronymHit) score += e.acronym === q ? 700 : 450;
    if (ok) {
      if (e.name.startsWith(q) || e.name.startsWith(`the ${q}`)) score += 600;
      if (inName === qTokens.length) score += 400;
      else if (inName + inAlt === qTokens.length) score += 300;
      else score += 150 + 20 * (inName + inAlt);
    }
    scored.push({ college: e.college, score });
  }

  scored.sort((a, b) => b.score - a.score || a.college.name.localeCompare(b.college.name));
  return scored.slice(0, limit).map((s) => s.college);
}

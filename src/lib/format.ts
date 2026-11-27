import { STATE_NAME } from '../data/states';
import type { College } from '../model/types';

/** "37%" or "<1%" for an estimate between 0 and 1 (estimates top out at 99%). */
export function formatChance(p: number): string {
  if (p < 0.005) return '<1%';
  return `${Math.min(99, Math.round(p * 100))}%`;
}

/** Numeric part only, for figures typeset separately from the % sign. */
export function chanceParts(p: number): { prefix: string; value: string } {
  if (p < 0.005) return { prefix: '<', value: '1' };
  return { prefix: '', value: String(Math.min(99, Math.round(p * 100))) };
}

export function formatRange(low: number, high: number): string {
  const lo = low < 0.005 ? '<1' : String(Math.min(99, Math.round(low * 100)));
  const hi = String(Math.min(99, Math.round(high * 100)));
  return lo === hi ? `${lo}%` : `${lo}–${hi}%`;
}

/** Admit rates keep one decimal under 10% so ultra-selective colleges stay distinct. */
export function formatRate(rate: number): string {
  if (rate >= 0.995) return '100%';
  const pct = rate * 100;
  return pct < 10 ? `${pct.toFixed(1)}%` : `${Math.round(pct)}%`;
}

/** Signed percentage points, e.g. "+6 pts", "−3 pts", "<1 pt". */
export function formatPoints(delta: number): string {
  const pts = delta * 100;
  if (Math.abs(pts) < 0.5) return Math.abs(pts) < 0.05 ? '0 pts' : `${pts > 0 ? '+' : '−'}<1 pt`;
  const n = Math.round(Math.abs(pts));
  return `${pts > 0 ? '+' : '−'}${n} ${n === 1 ? 'pt' : 'pts'}`;
}

export const formatCount = (n: number): string => n.toLocaleString('en-US');

export const collegeName = (c: College): string => c.short ?? c.name;

export function controlLabel(c: College): string {
  if (c.level === 2) return c.control === 'public' ? 'Community college' : c.control === 'for-profit' ? 'For-profit two-year' : 'Private two-year';
  if (c.control === 'for-profit') return 'For-profit';
  if (c.liberalArts) return c.control === 'public' ? 'Public liberal arts' : 'Liberal arts';
  return c.control === 'public' ? 'Public' : 'Private';
}

export const placeLabel = (c: College): string => (c.custom ? `Added by you${c.state !== '—' ? ` · ${c.state}` : ''}` : `${c.city}, ${c.state}`);

export const stateName = (code: string): string => STATE_NAME.get(code) ?? code;

const SKIP = new Set(['of', 'the', 'at', 'and', 'in', 'for', '&', 'de', 'la', '-', '–']);

/** Two- or three-letter monogram for a college's seal. */
export function monogram(c: College): string {
  if (c.short && c.short.length <= 4 && /^[A-Za-z&]+$/.test(c.short)) return c.short.toUpperCase();
  const alias = c.aka?.split('|').find((a) => /^[A-Z][A-Z&]{1,3}$/.test(a.trim()));
  if (alias) return alias.trim();
  const words = c.name
    .replace(/[,()]/g, ' ')
    .split(/[\s-–]+/)
    .filter((w) => w && !SKIP.has(w.toLowerCase()));
  return words
    .slice(0, 3)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 3);
}

export function websiteUrl(c: College): string | null {
  if (!c.web) return null;
  return /^https?:\/\//i.test(c.web) ? c.web : `https://${c.web}`;
}

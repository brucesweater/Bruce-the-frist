import type { Round, TierId } from './types';

export interface ScaleOption {
  label: string;
  description: string;
}

/**
 * Course rigor uses the same five levels counselors pick from on the
 * Common App School Report.
 */
export const RIGOR: readonly ScaleOption[] = [
  { label: 'Below average', description: 'Fewer advanced courses than most students at your school.' },
  { label: 'Average', description: 'A typical schedule with a few honors or AP classes.' },
  { label: 'Demanding', description: 'Several honors, AP, IB or dual-enrollment courses.' },
  { label: 'Very demanding', description: 'Advanced courses in most core subjects.' },
  { label: 'Most demanding', description: 'The hardest schedule your school offers.' },
];

export const ACTIVITIES: readonly ScaleOption[] = [
  { label: 'Limited', description: 'Few activities, or short-term involvement.' },
  { label: 'Involved', description: 'Steady participation in a few activities.' },
  { label: 'Leader', description: 'Leadership roles and years of commitment at school.' },
  { label: 'Regional standout', description: 'State or regional awards, or impact beyond your school.' },
  { label: 'National standout', description: 'National or international recognition, such as a top olympiad finish.' },
];

export const ESSAYS: readonly ScaleOption[] = [
  { label: 'Needs work', description: 'Generic, rushed or unpolished.' },
  { label: 'Good', description: 'Clear, correct and personal.' },
  { label: 'Strong', description: 'Memorable, with a distinct voice and real insight.' },
  { label: 'Exceptional', description: 'Readers will remember you and argue for you.' },
];

export const RECOMMENDATIONS: readonly ScaleOption[] = [
  { label: 'Average', description: 'Positive but general.' },
  { label: 'Strong', description: 'Specific praise from teachers who know you well.' },
  { label: 'Glowing', description: 'You are among the best students they have taught.' },
];

export interface TierInfo {
  id: TierId;
  label: string;
  /** Lowest chance that earns this tier. */
  min: number;
  /** 1 (long shot) – 5 (safety); also the number of filled bars in the tier glyph. */
  rank: number;
  blurb: string;
}

/** Ordered from lowest to highest chance. */
export const TIERS: readonly TierInfo[] = [
  { id: 'long-shot', label: 'Long shot', min: 0, rank: 1, blurb: 'Under 15%' },
  { id: 'reach', label: 'Reach', min: 0.15, rank: 2, blurb: '15–40%' },
  { id: 'target', label: 'Target', min: 0.4, rank: 3, blurb: '40–65%' },
  { id: 'likely', label: 'Likely', min: 0.65, rank: 4, blurb: '65–85%' },
  { id: 'safety', label: 'Safety', min: 0.85, rank: 5, blurb: '85% and up' },
];

export const tierInfo = (id: TierId): TierInfo => TIERS.find((t) => t.id === id) ?? TIERS[0];

export const ROUND_LABELS: Record<Round, { short: string; long: string; binding: boolean }> = {
  RD: { short: 'RD', long: 'Regular Decision', binding: false },
  EA: { short: 'EA', long: 'Early Action', binding: false },
  REA: { short: 'REA', long: 'Restrictive Early Action', binding: false },
  ED: { short: 'ED', long: 'Early Decision', binding: true },
  ED2: { short: 'ED II', long: 'Early Decision II', binding: true },
};

export type TestPolicy = 'required' | 'optional' | 'blind';
export type Control = 'public' | 'private' | 'for-profit';

/** Application rounds. RD (regular decision) is always available. */
export type Round = 'RD' | 'EA' | 'REA' | 'ED' | 'ED2';

export interface College {
  /** IPEDS unit ID, or "custom-…" for colleges the user entered. */
  id: string;
  name: string;
  /** Common short name used in lists and search, e.g. "MIT" or "UCLA". */
  short?: string;
  /** Extra search terms (official aliases). */
  aka?: string;
  city: string;
  /** USPS state or territory code. */
  state: string;
  control: Control;
  /** 4 = four-year college or university, 2 = two-year college. */
  level: 4 | 2;
  liberalArts?: boolean;
  /** Overall first-year admit rate, 0–1 (1 for open admission). */
  rate: number;
  /** Admits everyone with a high school diploma or equivalent. */
  openAdmission?: boolean;
  /** Public universities: admit rate for in-state applicants, when known. */
  inState?: number;
  /** Public universities: admit rate for out-of-state applicants, when known. */
  outState?: number;
  /** Middle 50% (25th–75th percentile) SAT total of enrolled first-years. */
  sat?: readonly [number, number];
  /** Middle 50% ACT composite of enrolled first-years. */
  act?: readonly [number, number];
  /** Average unweighted high school GPA of first-years, 4.0 scale. */
  gpa: number;
  /** True when the GPA is a statistical estimate rather than a reported figure. */
  gpaEstimated?: boolean;
  test: TestPolicy;
  /** Early rounds offered in addition to regular decision; undefined if not known. */
  rounds?: readonly Round[];
  /** Whether the college considers legacy status; undefined if not known. */
  legacy?: boolean;
  /** Undergraduate enrollment. */
  size?: number;
  /** First-year applicants (used to rank search results). */
  apps?: number;
  /** College website, without the protocol. */
  web?: string;
  tags?: readonly string[];
  /** True when details beyond the federal data were checked by hand. */
  curated?: boolean;
  /** True for colleges the user entered by hand. */
  custom?: boolean;
}

export type TestType = 'sat' | 'act' | 'none';

export interface Profile {
  /** Unweighted GPA on a 4.0 scale. */
  gpa: number | null;
  testType: TestType;
  sat: number | null;
  act: number | null;
  /** Course rigor, 0 (below average) – 4 (most demanding). */
  rigor: number;
  /** Activities and awards, 0 (limited) – 4 (national standout). */
  activities: number;
  /** Essays, 0 (needs work) – 3 (exceptional). */
  essays: number;
  /** Recommendations, 0 (average) – 2 (glowing). */
  recs: number;
  /** Home state code, 'INTL' for international applicants, or '' if not set. */
  residence: string;
  firstGen: boolean;
}

/** Per-college choices the student makes. */
export interface Plan {
  collegeId: string;
  round: Round;
  legacy: boolean;
  athlete: boolean;
}

export type TierId = 'long-shot' | 'reach' | 'target' | 'likely' | 'safety';

export interface Factor {
  id: string;
  label: string;
  /** Short explanation shown beside the bar, e.g. "1540 vs. 1500–1580". */
  detail: string;
  /** Change in the estimated chance (probability units) versus a typical profile. */
  delta: number;
}

export interface Note {
  kind: 'tip' | 'warning' | 'info';
  text: string;
}

export interface TestFit {
  kind: 'SAT' | 'ACT';
  you: number;
  p25: number;
  p75: number;
  /** Approximate percentile among enrolled students (0–1). */
  percentile: number;
  /** True when the range was converted from the other test. */
  converted: boolean;
}

export interface GpaFit {
  you: number;
  avg: number;
  /** Estimated middle-50% band around the average. */
  low: number;
  high: number;
  percentile: number;
}

/** Internal latent-index terms, kept so list-level odds can be computed. */
export interface Latent {
  mu: number;
  sigma: number;
  cut: number;
  tau: number;
}

export interface Estimate {
  collegeId: string;
  /** Estimated chance of admission (0–1). */
  chance: number;
  /** Likely range: 10th–90th percentile of plausible chances. */
  low: number;
  high: number;
  tier: TierId;
  /** Set when selectivity kept the tier lower than the chance alone suggests. */
  tierCap: TierId | null;
  /** Admit rate used as the starting point (adjusted for residency). */
  baseRate: number;
  baseRateLabel: 'overall' | 'in-state' | 'out-of-state';
  factors: Factor[];
  notes: Note[];
  testFit: TestFit | null;
  gpaFit: GpaFit | null;
  /** How test scores were handled for this college. */
  testMode: 'submitted' | 'test-optional' | 'missing-required' | 'blind' | 'no-data';
  latent: Latent;
}

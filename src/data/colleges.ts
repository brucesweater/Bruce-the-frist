import type { College, Control, Round, TestPolicy } from '../model/types';
import data from './colleges.json';

/**
 * Every U.S. college in the dataset, decoded from the compact rows written by
 * scripts/build-colleges.ts. Row layout:
 *
 *   0 id   1 name   2 short   3 aka   4 city   5 state   6 control (1 public,
 *   2 private nonprofit, 3 for-profit)   7 level (4 or 2)   8 admit rate
 *   9 flags (1 open admission, 2 liberal arts, 4 GPA estimated, 8 curated)
 *   10 in-state rate   11 out-of-state rate   12–13 SAT 25th/75th
 *   14–15 ACT 25th/75th   16 GPA   17 test policy (r/o/b)   18 early rounds
 *   19 legacy (1/0)   20 undergraduates   21 applicants   22 website   23 tags
 */
type Cell = string | number | null;

export interface DataMeta {
  source: string;
  admissionsYear: string;
  directoryYear: string;
  count: number;
  curated: number;
}

export const DATA_META: DataMeta = data.meta;

const CONTROLS: Record<number, Control> = { 1: 'public', 2: 'private', 3: 'for-profit' };
const TESTS: Record<string, TestPolicy> = { r: 'required', o: 'optional', b: 'blind' };

const opt = <T>(v: Cell | undefined): T | undefined => (v === null || v === undefined ? undefined : (v as T));

function decode(row: Cell[]): College {
  const flags = Number(row[9] ?? 0);
  const sat25 = opt<number>(row[12]);
  const sat75 = opt<number>(row[13]);
  const act25 = opt<number>(row[14]);
  const act75 = opt<number>(row[15]);
  const rounds = opt<string>(row[18]);
  const legacy = opt<number>(row[19]);
  const tags = opt<string>(row[23]);
  return {
    id: String(row[0]),
    name: String(row[1]),
    short: opt<string>(row[2]),
    aka: opt<string>(row[3]),
    city: String(row[4]),
    state: String(row[5]),
    control: CONTROLS[Number(row[6])] ?? 'private',
    level: row[7] === 2 ? 2 : 4,
    rate: Number(row[8]),
    openAdmission: (flags & 1) !== 0 || undefined,
    liberalArts: (flags & 2) !== 0 || undefined,
    gpaEstimated: (flags & 4) !== 0 || undefined,
    curated: (flags & 8) !== 0 || undefined,
    inState: opt<number>(row[10]),
    outState: opt<number>(row[11]),
    sat: sat25 !== undefined && sat75 !== undefined ? [sat25, sat75] : undefined,
    act: act25 !== undefined && act75 !== undefined ? [act25, act75] : undefined,
    gpa: Number(row[16]),
    test: TESTS[String(row[17])] ?? 'optional',
    rounds: rounds === undefined ? undefined : (rounds.split(' ').filter(Boolean) as Round[]),
    legacy: legacy === undefined ? undefined : legacy === 1,
    size: opt<number>(row[20]),
    apps: opt<number>(row[21]),
    web: opt<string>(row[22]),
    tags: tags ? tags.split('|') : undefined,
  };
}

export const COLLEGES: readonly College[] = (data.rows as Cell[][]).map(decode);

export const COLLEGE_BY_ID: ReadonlyMap<string, College> = new Map(COLLEGES.map((c) => [c.id, c]));

/**
 * Builds src/data/colleges.json from the U.S. Department of Education's IPEDS
 * data files (public domain), merged with the hand-checked details in
 * src/data/curated.ts.
 *
 * Usage:
 *   1. Download these "Complete data files" from
 *      https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx and unzip them into
 *      one folder (any layout; the newest year of each is used):
 *        HD<year>     Institutional characteristics: directory information
 *        IC<year>     Institutional characteristics: educational offerings
 *        ADM<year>    Admissions and test scores
 *        DRVEF<year>  Derived fall enrollment variables
 *   2. npm run build:data -- path/to/that/folder
 *
 * Which institutions are included: active, degree-granting colleges that offer
 * undergraduate programs at the two-year or four-year level in the 50 states,
 * D.C. and U.S. territories, and that either admit all applicants (open
 * admission) or report admissions data.
 */
import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { CURATED, type CuratedCollege } from '../src/data/curated';
import { actToSat } from '../src/model/concordance';

type Row = Record<string, string>;

/** RFC 4180 CSV parser (quoted fields, escaped quotes, CRLF). */
function parseCsv(text: string): Row[] {
  const records: string[][] = [];
  let field = '';
  let record: string[] = [];
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else quoted = false;
      } else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') {
      record.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      record.push(field);
      records.push(record);
      record = [];
      field = '';
    } else field += ch;
  }
  if (field !== '' || record.length) {
    record.push(field);
    records.push(record);
  }
  const header = records.shift()!.map((h) => h.replace(/^﻿/, '').trim().toUpperCase());
  return records
    .filter((r) => r.length > 1)
    .map((r) => Object.fromEntries(header.map((h, i) => [h, (r[i] ?? '').trim()])));
}

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((name: string) => {
    const p = join(dir, name);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}

/** Finds the newest "<PREFIX><year>.csv" (case-insensitive, revised "_rv" files preferred). */
function newest(files: string[], prefix: string): { path: string; year: number } {
  const re = new RegExp(`(?:^|[\\\\/])${prefix}(\\d{4})(_rv)?\\.csv$`, 'i');
  const found = files
    .map((path) => ({ path, m: re.exec(path) }))
    .filter((f): f is { path: string; m: RegExpExecArray } => f.m !== null)
    .map((f) => ({ path: f.path, year: Number(f.m[1]), rv: Boolean(f.m[2]) }))
    .sort((a, b) => b.year - a.year || Number(b.rv) - Number(a.rv));
  if (!found.length) throw new Error(`No ${prefix}<year>.csv file found`);
  return found[0];
}

const byId = (rows: Row[]) => new Map(rows.map((r) => [r.UNITID, r]));
const num = (s: string | undefined): number | null => {
  if (s === undefined || s === '' || s === '.') return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
};

const PLACES = new Set(
  ('AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY ' +
    'NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY PR GU VI AS MP').split(' '),
);

function cleanName(name: string): string {
  return name
    .replace(/[-–]\s*Main Campus$/i, '')
    .replace(/\s+Main Campus$/i, '')
    .replace(/^University of California-/, 'University of California, ')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanWeb(url: string): string | null {
  const u = url.trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
  return u ? u.replace(/^[^/]+/, (host) => host.toLowerCase()) : null;
}

/** Ordinary least squares with an intercept: returns [b0, b1, ...] and R². */
function ols(xs: number[][], ys: number[]): { coef: number[]; r2: number } {
  const X = xs.map((x) => [1, ...x]);
  const k = X[0].length;
  const A = Array.from({ length: k }, (_, i) => Array.from({ length: k }, (_, j) => X.reduce((s, r) => s + r[i] * r[j], 0)));
  const b = Array.from({ length: k }, (_, i) => X.reduce((s, r, n) => s + r[i] * ys[n], 0));
  // Gaussian elimination.
  for (let c = 0; c < k; c++) {
    const p = A.slice(c).reduce((best, row, i) => (Math.abs(row[c]) > Math.abs(A[best][c]) ? i + c : best), c);
    [A[c], A[p]] = [A[p], A[c]];
    [b[c], b[p]] = [b[p], b[c]];
    for (let r = c + 1; r < k; r++) {
      const f = A[r][c] / A[c][c];
      for (let j = c; j < k; j++) A[r][j] -= f * A[c][j];
      b[r] -= f * b[c];
    }
  }
  const coef = new Array<number>(k).fill(0);
  for (let r = k - 1; r >= 0; r--) coef[r] = (b[r] - A[r].slice(r + 1).reduce((s, a, j) => s + a * coef[r + 1 + j], 0)) / A[r][r];
  const mean = ys.reduce((s, y) => s + y, 0) / ys.length;
  const pred = X.map((r) => r.reduce((s, x, j) => s + x * coef[j], 0));
  const ssRes = ys.reduce((s, y, i) => s + (y - pred[i]) ** 2, 0);
  const ssTot = ys.reduce((s, y) => s + (y - mean) ** 2, 0);
  return { coef, r2: 1 - ssRes / ssTot };
}

const logit = (p: number) => Math.log(p / (1 - p));
const round = (x: number, d: number) => Math.round(x * 10 ** d) / 10 ** d;

function main() {
  const dir = process.argv[2];
  if (!dir) {
    console.error('Usage: npm run build:data -- <folder with unzipped IPEDS CSV files>');
    process.exit(1);
  }
  const files = walk(dir);
  const hdFile = newest(files, 'hd');
  const icFile = newest(files, 'ic');
  const admFile = newest(files, 'adm');
  const efFile = newest(files, 'drvef');
  const read = (f: { path: string }) => parseCsv(readFileSync(f.path, 'utf8'));
  const hd = read(hdFile);
  const ic = byId(read(icFile));
  const adm = byId(read(admFile));
  const ef = byId(read(efFile));
  const curated = new Map<string, CuratedCollege>(CURATED.map((c) => [c.id, c]));

  interface Draft {
    id: string;
    name: string;
    short: string | null;
    aka: string | null;
    city: string;
    state: string;
    control: 1 | 2 | 3;
    level: 4 | 2;
    rate: number;
    open: boolean;
    liberalArts: boolean;
    inState: number | null;
    outState: number | null;
    sat: [number, number] | null;
    act: [number, number] | null;
    gpa: number | null;
    test: 'r' | 'o' | 'b';
    rounds: string | null;
    legacy: 0 | 1 | null;
    size: number | null;
    apps: number | null;
    web: string | null;
    tags: string[];
    curated: CuratedCollege | undefined;
  }

  const drafts: Draft[] = [];
  const skipped: Record<string, number> = {};
  const skip = (why: string) => (skipped[why] = (skipped[why] ?? 0) + 1);

  for (const h of hd) {
    const id = h.UNITID;
    if (h.CYACTIVE !== '1' || h.PSEFLAG !== '1') { skip('inactive'); continue; }
    if (h.DEGGRANT !== '1' || h.UGOFFER !== '1') { skip('no undergraduate degrees'); continue; }
    if (h.ICLEVEL !== '1' && h.ICLEVEL !== '2') { skip('less than two-year'); continue; }
    if (h.SECTOR === '0') { skip('administrative unit'); continue; }
    if (!PLACES.has(h.STABBR)) { skip('outside the U.S.'); continue; }

    const a = adm.get(id);
    const apps = num(a?.APPLCN);
    const admits = num(a?.ADMSSN);
    const reported = apps !== null && admits !== null && apps >= 10;
    const openPolicy = ic.get(id)?.OPENADMP === '1';
    let rate: number;
    let open = false;
    if (reported && !(openPolicy && admits / apps >= 0.95)) rate = Math.min(1, admits / apps);
    else if (openPolicy) {
      rate = 1;
      open = true;
    } else { skip('no first-year admissions data'); continue; }

    const satLo = (num(a?.SATVR25) ?? NaN) + (num(a?.SATMT25) ?? NaN);
    const satHi = (num(a?.SATVR75) ?? NaN) + (num(a?.SATMT75) ?? NaN);
    const actLo = num(a?.ACTCM25);
    const actHi = num(a?.ACTCM75);
    const sat: [number, number] | null =
      Number.isFinite(satLo) && Number.isFinite(satHi) && satHi > satLo ? [round(satLo, -1), round(satHi, -1)] : null;
    const act: [number, number] | null = actLo !== null && actHi !== null && actHi > actLo ? [actLo, actHi] : null;
    const test: Draft['test'] = a?.ADMCON7 === '1' ? 'r' : a?.ADMCON7 === '3' ? 'b' : 'o';

    const cur = curated.get(id);
    const tags: string[] = [...(cur?.tags ?? [])];
    if (h.HBCU === '1' && !tags.includes('HBCU')) tags.push('HBCU');
    if (h.TRIBAL === '1') tags.push('Tribal college');

    const aliases = h.IALIAS.split(/[|,;]/).map((s) => s.trim()).filter(Boolean);
    const aka = [...(cur?.aka ?? []), ...aliases].filter((s, i, all) => all.indexOf(s) === i).join('|').slice(0, 160);

    drafts.push({
      id,
      name: cur?.name ?? cleanName(h.INSTNM),
      short: cur?.short ?? null,
      aka: aka || null,
      city: h.CITY,
      state: h.STABBR,
      control: h.CONTROL === '1' ? 1 : h.CONTROL === '2' ? 2 : 3,
      level: h.ICLEVEL === '1' ? 4 : 2,
      rate: round(rate, 4),
      open,
      liberalArts: cur?.liberalArts ?? h.C21BASIC === '21',
      inState: cur?.inState ?? null,
      outState: cur?.outState ?? null,
      sat,
      act,
      gpa: cur?.gpa ?? null,
      test: cur ? (cur.test === 'required' ? 'r' : cur.test === 'blind' ? 'b' : 'o') : test,
      rounds: cur ? cur.rounds.join(' ') : null,
      legacy: cur ? (cur.legacy ? 1 : 0) : null,
      size: num(ef.get(id)?.EFUG),
      apps,
      web: cleanWeb(h.WEBADDR),
      tags,
      curated: cur,
    });
  }

  // Estimate average GPA where no hand-checked figure exists, from the
  // relationship between GPA, test scores and selectivity among curated colleges.
  const satMid = (d: Draft): number | null =>
    d.sat ? (d.sat[0] + d.sat[1]) / 2 : d.act ? actToSat((d.act[0] + d.act[1]) / 2) : null;
  const train = drafts.filter((d) => d.curated && !d.open);
  const withTests = train.filter((d) => satMid(d) !== null);
  const fitTests = ols(withTests.map((d) => [satMid(d)!, logit(Math.min(0.98, d.rate))]), withTests.map((d) => d.gpa!));
  const fitRate = ols(train.map((d) => [logit(Math.min(0.98, d.rate))]), train.map((d) => d.gpa!));
  let estimated = 0;
  for (const d of drafts) {
    if (d.gpa !== null) continue;
    const lr = logit(Math.min(0.98, d.rate));
    const s = satMid(d);
    const g = s !== null ? fitTests.coef[0] + fitTests.coef[1] * s + fitTests.coef[2] * lr : fitRate.coef[0] + fitRate.coef[1] * lr;
    d.gpa = round(Math.min(3.97, Math.max(2.8, g)), 2);
    estimated++;
  }

  for (const c of CURATED) if (!drafts.some((d) => d.id === c.id)) console.warn(`Curated college ${c.slug} (${c.id}) is not in the IPEDS universe`);
  for (const d of drafts) {
    if (d.inState !== null && d.outState !== null) {
      const lo = Math.min(d.inState, d.outState) - 0.05;
      const hi = Math.max(d.inState, d.outState) + 0.05;
      if (d.rate < lo || d.rate > hi) console.warn(`${d.name}: overall rate ${d.rate} is outside its residency rates`);
    }
  }

  drafts.sort((a, b) => a.name.localeCompare(b.name));
  // Row layout (keep in sync with src/data/colleges.ts). Trailing nulls are dropped.
  const rows = drafts.map((d) => {
    const flags = (d.open ? 1 : 0) | (d.liberalArts ? 2 : 0) | (d.curated ? 0 : 4) | (d.curated ? 8 : 0);
    const row: unknown[] = [
      d.id, d.name, d.short, d.aka, d.city, d.state, d.control, d.level, d.rate, flags,
      d.inState, d.outState, d.sat?.[0] ?? null, d.sat?.[1] ?? null, d.act?.[0] ?? null, d.act?.[1] ?? null,
      d.gpa, d.test, d.rounds, d.legacy, d.size, d.apps, d.web, d.tags.length ? d.tags.join('|') : null,
    ];
    while (row.length && row[row.length - 1] === null) row.pop();
    return row;
  });

  const meta = {
    source: 'U.S. Department of Education, IPEDS',
    admissionsYear: `Fall ${admFile.year}`,
    directoryYear: `${hdFile.year}–${String((hdFile.year + 1) % 100).padStart(2, '0')}`,
    files: [hdFile, icFile, admFile, efFile].map((f) => f.path.split(/[\\/]/).pop()),
    count: rows.length,
    curated: drafts.filter((d) => d.curated).length,
    gpaModel: { withTests: fitTests.coef.map((c) => round(c, 6)), rateOnly: fitRate.coef.map((c) => round(c, 6)) },
  };
  const out = '{"meta":' + JSON.stringify(meta) + ',\n"rows":[\n' + rows.map((r) => JSON.stringify(r)).join(',\n') + '\n]}\n';
  writeFileSync(new URL('../src/data/colleges.json', import.meta.url), out);

  console.log(`Wrote ${rows.length} colleges (${meta.curated} curated, ${estimated} with estimated GPA).`);
  console.log(`  open admission: ${drafts.filter((d) => d.open).length}; two-year: ${drafts.filter((d) => d.level === 2).length}`);
  console.log(`  GPA fit with tests R²=${fitTests.r2.toFixed(2)} (n=${withTests.length}); rate only R²=${fitRate.r2.toFixed(2)} (n=${train.length})`);
  console.log('  skipped:', skipped);
  console.log(`  ${(out.length / 1024).toFixed(0)} KB`);
}

main();

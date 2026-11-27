// SAT ↔ ACT conversion based on the official 2018 ACT/SAT concordance tables.
// Each pair is [ACT composite, SAT total] using the table's single-score values.

const TABLE: ReadonlyArray<readonly [number, number]> = [
  [9, 590], [10, 630], [11, 670], [12, 710], [13, 760], [14, 800], [15, 850],
  [16, 890], [17, 930], [18, 970], [19, 1010], [20, 1040], [21, 1080],
  [22, 1110], [23, 1140], [24, 1180], [25, 1210], [26, 1240], [27, 1280],
  [28, 1310], [29, 1340], [30, 1370], [31, 1400], [32, 1430], [33, 1460],
  [34, 1500], [35, 1540], [36, 1590],
];

function interpolate(x: number, from: 0 | 1, to: 0 | 1): number {
  const first = TABLE[0];
  const last = TABLE[TABLE.length - 1];
  if (x <= first[from]) {
    // Extend the bottom of the table with the slope of its first segment.
    const [a, b] = [TABLE[0], TABLE[1]];
    const slope = (b[to] - a[to]) / (b[from] - a[from]);
    return a[to] + (x - a[from]) * slope;
  }
  if (x >= last[from]) return last[to];
  for (let i = 1; i < TABLE.length; i++) {
    const lo = TABLE[i - 1];
    const hi = TABLE[i];
    if (x <= hi[from]) {
      const f = (x - lo[from]) / (hi[from] - lo[from]);
      return lo[to] + f * (hi[to] - lo[to]);
    }
  }
  return last[to];
}

/** Continuous ACT → SAT conversion (for comparing against SAT ranges). */
export const actToSat = (act: number): number => Math.min(1600, Math.max(400, interpolate(act, 0, 1)));

/** Continuous SAT → ACT conversion (for comparing against ACT ranges). */
export const satToAct = (sat: number): number => Math.min(36, Math.max(1, interpolate(sat, 1, 0)));

/** Rounded equivalents for display, e.g. "SAT 1460 is about ACT 33". */
export const roundedActFor = (sat: number): number => Math.round(satToAct(sat));
export const roundedSatFor = (act: number): number => Math.round(actToSat(act) / 10) * 10;

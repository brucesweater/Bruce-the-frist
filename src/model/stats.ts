// Small, dependency-free statistics helpers used by the admission model.

export const clamp = (x: number, lo: number, hi: number): number =>
  Math.min(hi, Math.max(lo, x));

export const logit = (p: number): number => Math.log(p / (1 - p));
export const logistic = (x: number): number => 1 / (1 + Math.exp(-x));

/** Complementary error function (Numerical Recipes erfcc, |relative error| < 1.2e-7). */
export function erfc(x: number): number {
  const z = Math.abs(x);
  const t = 1 / (1 + 0.5 * z);
  const r =
    t *
    Math.exp(
      -z * z -
        1.26551223 +
        t *
          (1.00002368 +
            t *
              (0.37409196 +
                t *
                  (0.09678418 +
                    t *
                      (-0.18628806 +
                        t *
                          (0.27886807 +
                            t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))),
    );
  return x >= 0 ? r : 2 - r;
}

/** Standard normal cumulative distribution function, Φ(x). */
export const normCdf = (x: number): number => 0.5 * erfc(-x / Math.SQRT2);

/** Standard normal density, φ(x). */
export const normPdf = (x: number): number => Math.exp(-0.5 * x * x) / Math.sqrt(2 * Math.PI);

const A = [-39.69683028665376, 220.9460984245205, -275.9285104469687, 138.357751867269, -30.66479806614716, 2.506628277459239];
const B = [-54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155288572];
const C = [-0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783];
const D = [0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416];

/** Inverse of the standard normal CDF, Φ⁻¹(p) (Acklam's algorithm + one Halley step). */
export function normInv(p: number): number {
  if (p <= 0) return -Infinity;
  if (p >= 1) return Infinity;
  const plow = 0.02425;
  let x: number;
  if (p < plow) {
    const q = Math.sqrt(-2 * Math.log(p));
    x = (((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5]) / ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1);
  } else if (p <= 1 - plow) {
    const q = p - 0.5;
    const r = q * q;
    x = ((((((A[0] * r + A[1]) * r + A[2]) * r + A[3]) * r + A[4]) * r + A[5]) * q) / (((((B[0] * r + B[1]) * r + B[2]) * r + B[3]) * r + B[4]) * r + 1);
  } else {
    const q = Math.sqrt(-2 * Math.log(1 - p));
    x = -(((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5]) / ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1);
  }
  // One step of Halley's method tightens the approximation.
  const e = normCdf(x) - p;
  const u = e * Math.sqrt(2 * Math.PI) * Math.exp((x * x) / 2);
  return x - u / (1 + (x * u) / 2);
}

export interface Node {
  z: number;
  w: number;
}

/**
 * Quadrature nodes for expectations over a standard normal variable:
 * E[f(Z)] ≈ Σ w·f(z). A fine, evenly spaced grid is plenty for the smooth
 * functions used here and is easy to reason about.
 */
export const NORMAL_NODES: readonly Node[] = (() => {
  const nodes: Node[] = [];
  const step = 0.125;
  for (let z = -6; z <= 6 + 1e-9; z += step) nodes.push({ z, w: normPdf(z) });
  const total = nodes.reduce((s, n) => s + n.w, 0);
  return nodes.map((n) => ({ z: n.z, w: n.w / total }));
})();

/** Expected value of f(Z) for Z ~ N(0, 1). */
export function expectNormal(f: (z: number) => number): number {
  let s = 0;
  for (const n of NORMAL_NODES) s += n.w * f(n.z);
  return s;
}

/** Linear interpolation into an array indexed 0..n-1 at a fractional position. */
export function interpIndex(values: readonly number[], position: number): number {
  const p = clamp(position, 0, values.length - 1);
  const i = Math.floor(p);
  if (i >= values.length - 1) return values[values.length - 1];
  const f = p - i;
  return values[i] * (1 - f) + values[i + 1] * f;
}

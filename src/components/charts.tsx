import { formatChance, formatPoints, formatRange } from '../lib/format';
import { TIERS, tierInfo } from '../model/scales';
import type { Factor, TierId } from '../model/types';

const pct = (x: number) => `${Math.max(0, Math.min(100, x * 100))}%`;

/** Tier boundaries in percent, used to notch the meter track. */
const ZONES = TIERS.map((t, i) => (TIERS[i + 1]?.min ?? 1) - t.min);

/**
 * Bullet-style meter: the lighter band is the likely range, the solid bar
 * the estimate, and the notches in the track mark the tier boundaries.
 */
export function ChanceMeter({ chance, low, high, size = 'row' }: { chance: number; low: number; high: number; size?: 'row' | 'lg' }) {
  return (
    <div
      className={`meter meter-${size}`}
      role="img"
      aria-label={`Estimated chance ${formatChance(chance)}, likely range ${formatRange(low, high)}`}
    >
      <div className="meter-track" aria-hidden="true">
        {ZONES.map((w, i) => (
          <span key={i} style={{ flexGrow: w }} />
        ))}
      </div>
      <div className="meter-band" style={{ left: pct(low), width: pct(high - low) }} />
      <div className="meter-fill" style={{ width: pct(chance) }} />
    </div>
  );
}

export function TierGlyph({ tier }: { tier: TierId }) {
  const rank = tierInfo(tier).rank;
  return (
    <svg className="tier-glyph" width="19" height="14" viewBox="0 0 19 14" aria-hidden="true" focusable="false">
      {[0, 1, 2, 3, 4].map((i) => (
        <rect
          key={i}
          x={i * 4}
          y={13 - (5 + i * 2)}
          width="3"
          height={5 + i * 2}
          rx="1"
          fill={i < rank ? `var(--tier-${rank})` : 'var(--line-2)'}
        />
      ))}
    </svg>
  );
}

export function TierPill({ tier, title }: { tier: TierId; title?: string }) {
  return (
    <span className="tier-pill" data-tier={tier} title={title}>
      <TierGlyph tier={tier} />
      {tierInfo(tier).label}
    </span>
  );
}

/** One whole (the list) split by tier; counts printed on the blocks. */
export function TierBar({ counts }: { counts: Record<TierId, number> }) {
  const total = TIERS.reduce((s, t) => s + counts[t.id], 0);
  if (!total) return null;
  const summary = TIERS.filter((t) => counts[t.id])
    .map((t) => `${counts[t.id]} ${t.label.toLowerCase()}`)
    .join(', ');
  return (
    <figure className="tier-bar">
      <div className="tier-bar-track" role="img" aria-label={`Your list by chance: ${summary}`}>
        {TIERS.filter((t) => counts[t.id] > 0).map((t) => (
          <span
            key={t.id}
            className="tier-block"
            style={{ flexGrow: counts[t.id], background: `var(--tier-${t.rank})`, color: `var(--on-tier-${t.rank})` }}
            title={`${t.label} (${t.blurb}): ${counts[t.id]} ${counts[t.id] === 1 ? 'college' : 'colleges'}`}
          >
            {counts[t.id]}
          </span>
        ))}
      </div>
      <figcaption className="tier-legend">
        {TIERS.map((t) => (
          <span key={t.id} className="tier-legend-item" data-empty={counts[t.id] === 0 || undefined}>
            <i style={{ background: `var(--tier-${t.rank})` }} />
            <span className="tier-legend-name">{t.label}</span>
            <span className="tier-legend-range">{t.blurb}</span>
          </span>
        ))}
      </figcaption>
    </figure>
  );
}

const DOMAINS = { SAT: [800, 1600], ACT: [12, 36], GPA: [2.5, 4] } as const;

/** Where the student sits against the college's middle 50%. */
export function FitBar({
  kind,
  you,
  low,
  high,
  mid,
  text,
}: {
  kind: keyof typeof DOMAINS;
  you: number;
  low: number;
  high: number;
  /** Optional tick for the average. */
  mid?: number;
  text: React.ReactNode;
}) {
  const [d0, d1] = DOMAINS[kind];
  const at = (v: number) => pct((Math.min(d1, Math.max(d0, v)) - d0) / (d1 - d0));
  const fmt = (v: number) => (kind === 'GPA' ? v.toFixed(1) : String(v));
  return (
    <div className="fit">
      <span className="fit-label mono">{kind}</span>
      <div className="fit-plot" aria-hidden="true">
        <div className="fit-track" />
        <div className="fit-band" style={{ left: at(low), width: `calc(${at(high)} - ${at(low)})` }} />
        {mid !== undefined && <div className="fit-tick" style={{ left: at(mid) }} />}
        <div className="fit-you" style={{ left: at(you) }} data-clamped={you < d0 || you > d1 || undefined} />
        <span className="fit-axis fit-axis-start mono">{fmt(d0)}</span>
        <span className="fit-axis fit-axis-end mono">{fmt(d1)}</span>
      </div>
      <p className="fit-text">{text}</p>
    </div>
  );
}

/** Diverging bars: how much each factor moves the estimate versus a typical profile. */
export function FactorBars({ factors }: { factors: readonly Factor[] }) {
  const maxAbs = Math.max(0.04, ...factors.map((f) => Math.abs(f.delta)));
  return (
    <ul className="factors">
      {factors.map((f) => {
        const w = (Math.abs(f.delta) / maxAbs) * 50;
        const helps = f.delta > 0;
        return (
          <li key={f.id} className="factor" title={`${f.label}: ${f.detail}. ${formatPoints(f.delta)} compared with a typical profile.`}>
            <span className="factor-name">
              <span className="factor-label">{f.label}</span>
              <span className="factor-detail">{f.detail}</span>
            </span>
            <span className="factor-plot" aria-hidden="true">
              <span className="factor-zero" />
              {Math.abs(f.delta) >= 0.0005 && (
                <span
                  className="factor-bar"
                  data-dir={helps ? 'up' : 'down'}
                  style={helps ? { left: '50%', width: `${w}%` } : { right: '50%', width: `${w}%` }}
                />
              )}
            </span>
            <span className="factor-value tabular">{formatPoints(f.delta)}</span>
          </li>
        );
      })}
    </ul>
  );
}

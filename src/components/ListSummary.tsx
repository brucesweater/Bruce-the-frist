import { forwardRef } from 'react';
import { chanceParts, formatChance, formatRange } from '../lib/format';
import { useTweened } from '../lib/hooks';
import type { ListOutlook } from '../model/list';
import type { Note } from '../model/types';
import { TierBar } from './charts';
import { InfoIcon, TipIcon, WarningIcon } from './icons';

export function NoteIcon({ kind }: { kind: Note['kind'] }) {
  const Icon = kind === 'warning' ? WarningIcon : kind === 'tip' ? TipIcon : InfoIcon;
  return <Icon size={16} className="note-icon" />;
}

export function NoteList({ notes, className = '' }: { notes: readonly Note[]; className?: string }) {
  if (!notes.length) return null;
  return (
    <ul className={`notes ${className}`}>
      {notes.map((n) => (
        <li key={n.text} className="note" data-kind={n.kind}>
          <NoteIcon kind={n.kind} />
          <span>
            <span className="visually-hidden">{n.kind === 'warning' ? 'Warning: ' : n.kind === 'tip' ? 'Tip: ' : 'Note: '}</span>
            {n.text}
          </span>
        </li>
      ))}
    </ul>
  );
}

export const ListSummary = forwardRef<
  HTMLElement,
  {
    outlook: ListOutlook;
    hasGpa: boolean;
    onPickCollege: () => void;
    onEnterGpa: () => void;
  }
>(function ListSummary({ outlook, hasGpa, onPickCollege, onEnterGpa }, ref) {
  const tweened = useTweened(outlook.atLeastOne);
  const parts = chanceParts(tweened);
  const ready = hasGpa && outlook.count > 0;

  return (
    <section ref={ref} className="summary card" aria-labelledby="summary-title">
      <div className="summary-top">
        <div className="hero-figure">
          <h2 className="eyebrow" id="summary-title">
            Chance of at least one acceptance
          </h2>
          {ready ? (
            <>
              <p className="hero-number" aria-label={formatChance(outlook.atLeastOne).replace('<', 'under ').replace('%', ' percent')}>
                <span className="hero-highlight">
                  {parts.prefix && <span className="hero-prefix">{parts.prefix}</span>}
                  {parts.value}
                  <span className="hero-pct">%</span>
                </span>
              </p>
              <p className="hero-sub">
                {formatRange(outlook.atLeastOneLow, outlook.atLeastOneHigh).includes('–')
                  ? `Likely range ${formatRange(outlook.atLeastOneLow, outlook.atLeastOneHigh)}, across `
                  : 'Across '}
                {outlook.count} {outlook.count === 1 ? 'college' : 'colleges'}
              </p>
            </>
          ) : (
            <div className="hero-empty">
              <p className="hero-number hero-number-empty" aria-hidden="true">
                <span>—</span>
              </p>
              {!hasGpa ? (
                <p className="hero-sub">
                  <button type="button" className="link-btn" onClick={onEnterGpa}>
                    Enter your GPA
                  </button>{' '}
                  to see your chances.
                </p>
              ) : (
                <p className="hero-sub">
                  <button type="button" className="link-btn" onClick={onPickCollege}>
                    Add colleges
                  </button>{' '}
                  to see your odds across a list.
                </p>
              )}
            </div>
          )}
        </div>
        {ready && (
          <dl className="stat-tiles">
            <div className="stat">
              <dt>Expected acceptances</dt>
              <dd>
                {outlook.expected.toFixed(1)} <small>of {outlook.count}</small>
              </dd>
            </div>
            <div className="stat">
              <dt>Reaches and long shots</dt>
              <dd>
                {outlook.tiers['long-shot'] + outlook.tiers.reach} <small>of {outlook.count}</small>
              </dd>
            </div>
          </dl>
        )}
      </div>
      {ready && (
        <>
          <TierBar counts={outlook.tiers} />
          <NoteList notes={outlook.advice} className="advice" />
        </>
      )}
    </section>
  );
});

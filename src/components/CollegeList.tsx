import { useLayoutEffect, useRef, type Dispatch } from 'react';
import { formatChance, formatRange, formatRate } from '../lib/format';
import { tierInfo } from '../model/scales';
import type { College, Estimate, Plan } from '../model/types';
import type { Action, SortKey, ViewMode } from '../state/store';
import { TierPill } from './charts';
import { CollegeRow } from './CollegeRow';
import { Segmented } from './controls';
import { ListIcon, TableIcon } from './icons';

export interface ListItem {
  college: College;
  plan: Plan;
  estimate: Estimate | null;
}

export function sortItems(items: ListItem[], sort: SortKey): ListItem[] {
  const byName = (a: ListItem, b: ListItem) => a.college.name.localeCompare(b.college.name);
  const sorted = [...items];
  if (sort === 'name') sorted.sort(byName);
  else if (sort === 'rate') sorted.sort((a, b) => a.college.rate - b.college.rate || byName(a, b));
  else sorted.sort((a, b) => (b.estimate?.chance ?? 0) - (a.estimate?.chance ?? 0) || a.college.rate - b.college.rate || byName(a, b));
  return sorted;
}

/** Animates rows sliding into their new places when the order changes (FLIP). */
function useReorderAnimation(listRef: React.RefObject<HTMLOListElement | null>, order: string) {
  const positions = useRef(new Map<string, number>());
  useLayoutEffect(() => {
    const list = listRef.current;
    if (!list) return;
    const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    const rows = Array.from(list.querySelectorAll<HTMLElement>(':scope > .row'));
    for (const row of rows) {
      const id = row.dataset.id!;
      const top = row.getBoundingClientRect().top;
      const before = positions.current.get(id);
      positions.current.set(id, top);
      if (reduce || before === undefined || Math.abs(before - top) < 1) continue;
      row.animate([{ transform: `translateY(${before - top}px)` }, { transform: 'translateY(0)' }], {
        duration: 320,
        easing: 'cubic-bezier(0.2, 0.7, 0.2, 1)',
      });
    }
  }, [order, listRef]);
}

export function CollegeList({
  items,
  sort,
  view,
  expanded,
  onToggle,
  dispatch,
  freshId,
}: {
  items: ListItem[];
  sort: SortKey;
  view: ViewMode;
  expanded: ReadonlySet<string>;
  onToggle: (id: string) => void;
  dispatch: Dispatch<Action>;
  freshId: string | null;
}) {
  const sorted = sortItems(items, sort);
  const listRef = useRef<HTMLOListElement>(null);
  useReorderAnimation(listRef, sorted.map((i) => i.college.id).join(','));

  return (
    <section className="college-list" aria-labelledby="list-title">
      <div className="list-head">
        <h2 id="list-title">
          Your colleges <span className="count">{items.length}</span>
        </h2>
        {items.length > 0 && (
          <div className="list-controls">
            <Segmented<SortKey>
              id="sort"
              label="Sort by"
              size="sm"
              value={sort}
              onChange={(s) => dispatch({ type: 'sort', sort: s })}
              options={[
                { value: 'chance', label: 'Chance' },
                { value: 'rate', label: 'Admit rate' },
                { value: 'name', label: 'Name' },
              ]}
            />
            <Segmented<ViewMode>
              id="view"
              label="View"
              hideLabel
              size="sm"
              value={view}
              onChange={(v) => dispatch({ type: 'view', view: v })}
              options={[
                { value: 'list', label: <ListIcon size={16} aria-label="List" />, title: 'List' },
                { value: 'table', label: <TableIcon size={16} aria-label="Table" />, title: 'Table' },
              ]}
            />
          </div>
        )}
      </div>

      {items.length === 0 ? null : view === 'table' ? (
        <CollegeTable items={sorted} onOpen={(id) => {
          dispatch({ type: 'view', view: 'list' });
          if (!expanded.has(id)) onToggle(id);
        }} />
      ) : (
        <ol className="rows" ref={listRef}>
          {sorted.map(({ college, plan, estimate }) => (
            <CollegeRow
              key={college.id}
              college={college}
              plan={plan}
              estimate={estimate}
              expanded={expanded.has(college.id)}
              onToggle={() => onToggle(college.id)}
              dispatch={dispatch}
              fresh={freshId === college.id}
            />
          ))}
        </ol>
      )}
    </section>
  );
}

const range = (r?: readonly [number, number]) => (r ? `${r[0]}–${r[1]}` : '—');

function CollegeTable({ items, onOpen }: { items: ListItem[]; onOpen: (id: string) => void }) {
  return (
    <div className="table-wrap" tabIndex={0} role="region" aria-label="Your colleges as a table">
      <table className="table">
        <thead>
          <tr>
            <th scope="col">College</th>
            <th scope="col" className="num">Chance</th>
            <th scope="col" className="num">Likely range</th>
            <th scope="col">Tier</th>
            <th scope="col" className="num">Admit rate</th>
            <th scope="col" className="num">SAT 25–75</th>
            <th scope="col" className="num">ACT 25–75</th>
            <th scope="col" className="num">Avg GPA</th>
          </tr>
        </thead>
        <tbody>
          {items.map(({ college: c, estimate: e }) => (
            <tr key={c.id}>
              <th scope="row">
                <button type="button" className="link-btn" onClick={() => onOpen(c.id)}>
                  {c.short ?? c.name}
                </button>
                <span className="table-sub">
                  {c.city}, {c.state}
                </span>
              </th>
              <td className="num strong">{e ? formatChance(e.chance) : '—'}</td>
              <td className="num">{e ? formatRange(e.low, e.high) : '—'}</td>
              <td>{e ? <TierPill tier={e.tier} title={tierInfo(e.tier).blurb} /> : '—'}</td>
              <td className="num">{c.openAdmission ? 'Open' : formatRate(c.rate)}</td>
              <td className="num">{c.test === 'blind' ? 'Not used' : range(c.sat)}</td>
              <td className="num">{c.test === 'blind' ? 'Not used' : range(c.act)}</td>
              <td className="num">
                {c.gpa.toFixed(2)}
                {c.gpaEstimated && <span className="est">*</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {items.some((i) => i.college.gpaEstimated) && <p className="table-foot">* Estimated from test scores and admit rate.</p>}
    </div>
  );
}

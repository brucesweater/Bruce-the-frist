import { forwardRef, useEffect, useId, useImperativeHandle, useMemo, useRef, useState } from 'react';
import { searchColleges } from '../data/search';
import { controlLabel, formatCount, formatRate, placeLabel } from '../lib/format';
import type { College } from '../model/types';
import { CheckIcon, PencilIcon, PlusIcon, SearchIcon } from './icons';
import { Seal } from './Seal';

/** True on phone-width screens, where the long placeholder would be cut off. */
function useNarrow() {
  const query = '(max-width: 560px)';
  const [narrow, setNarrow] = useState(() => typeof window !== 'undefined' && window.matchMedia?.(query).matches);
  useEffect(() => {
    const mq = window.matchMedia?.(query);
    if (!mq) return;
    const on = () => setNarrow(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return narrow;
}

export interface CollegeSearchHandle {
  focus: () => void;
}

/** Combobox for adding colleges: type a name, abbreviation, city or state. */
export const CollegeSearch = forwardRef<
  CollegeSearchHandle,
  {
    colleges: readonly College[];
    inList: ReadonlySet<string>;
    onAdd: (college: College) => void;
    onAddCustom: (name: string) => void;
  }
>(function CollegeSearch({ colleges, inList, onAdd, onAddCustom }, ref) {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const listId = useId();
  const results = useMemo(() => searchColleges(colleges, query, 8), [colleges, query]);
  const showPopup = open && query.trim().length > 0;
  const narrow = useNarrow();

  useImperativeHandle(ref, () => ({ focus: () => inputRef.current?.focus() }), []);

  const choose = (c: College | undefined) => {
    if (!c || inList.has(c.id)) return;
    onAdd(c);
    setQuery('');
    setActive(0);
  };

  return (
    <div className="search">
      <label htmlFor="college-search" className="visually-hidden">
        Add a college
      </label>
      <div className="search-box">
        <SearchIcon className="search-icon" />
        <input
          ref={inputRef}
          id="college-search"
          type="text"
          role="combobox"
          aria-expanded={showPopup}
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={showPopup && results[active] ? `${listId}-${results[active].id}` : undefined}
          autoComplete="off"
          spellCheck={false}
          placeholder={narrow ? `Search ${formatCount(colleges.length)} colleges` : `Search ${formatCount(colleges.length)} colleges by name, city or state`}
          value={query}
          onChange={(e) => {
            setQuery(e.currentTarget.value);
            setActive(0);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onBlur={() => setOpen(false)}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              setOpen(true);
              setActive((a) => Math.min(results.length - 1, a + 1));
            } else if (e.key === 'ArrowUp') {
              e.preventDefault();
              setActive((a) => Math.max(0, a - 1));
            } else if (e.key === 'Enter') {
              e.preventDefault();
              choose(results[active]);
            } else if (e.key === 'Escape') {
              if (query) setQuery('');
              else setOpen(false);
            }
          }}
        />
        <kbd className="search-kbd" aria-hidden="true">
          /
        </kbd>
      </div>
      {showPopup && (
        <div className="search-popup" onMouseDown={(e) => e.preventDefault()}>
          <ul id={listId} role="listbox" aria-label="Matching colleges" className="search-results">
            {results.map((c, i) => {
              const added = inList.has(c.id);
              return (
                <li
                  key={c.id}
                  id={`${listId}-${c.id}`}
                  role="option"
                  aria-selected={i === active}
                  aria-disabled={added || undefined}
                  className="search-option"
                  onMouseEnter={() => setActive(i)}
                  onClick={() => choose(c)}
                >
                  <Seal college={c} size="sm" />
                  <span className="search-option-main">
                    <span className="search-option-name">{c.name}</span>
                    <span className="search-option-meta">
                      {placeLabel(c)} · {controlLabel(c)} · {c.openAdmission ? 'Open admission' : `${formatRate(c.rate)} admitted`}
                    </span>
                  </span>
                  <span className="search-option-action" data-added={added || undefined}>
                    {added ? (
                      <>
                        <CheckIcon size={16} /> Added
                      </>
                    ) : (
                      <PlusIcon size={16} />
                    )}
                  </span>
                </li>
              );
            })}
          </ul>
          {results.length === 0 && <p className="search-empty">No U.S. colleges match “{query.trim()}”.</p>}
          <button type="button" className="search-custom" onClick={() => onAddCustom(query.trim())}>
            <PencilIcon size={16} />
            {results.length ? 'Not here? Add a college by hand' : `Add “${query.trim()}” by hand`}
          </button>
        </div>
      )}
    </div>
  );
});

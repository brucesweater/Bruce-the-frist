import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { CollegeList, type ListItem } from './components/CollegeList';
import { CollegeSearch, type CollegeSearchHandle } from './components/CollegeSearch';
import { CustomCollegeForm, Dialog, HowItWorks } from './components/Dialogs';
import { Header } from './components/Header';
import { PlusIcon } from './components/icons';
import { ListSummary } from './components/ListSummary';
import { ProfilePanel } from './components/ProfilePanel';
import { COLLEGES, DATA_META } from './data/colleges';
import { idForSlug } from './data/curated';
import { chanceParts, collegeName, formatCount } from './lib/format';
import { useInView } from './lib/hooks';
import { useTheme } from './lib/theme';
import { estimateChance } from './model/admission';
import { listOutlook } from './model/list';
import type { College, Estimate } from './model/types';
import { useAppState } from './state/store';

const SUGGESTIONS = ['harvard', 'stanford', 'mit', 'ucla', 'umich', 'nyu', 'ut-austin', 'uf', 'osu', 'asu'].map(idForSlug);

const isTyping = (t: EventTarget | null) =>
  t instanceof HTMLElement && (t.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(t.tagName));

export default function App() {
  const [state, dispatch] = useAppState();
  const theme = useTheme();
  const [howOpen, setHowOpen] = useState(false);
  const [customName, setCustomName] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(() => new Set());
  const [freshId, setFreshId] = useState<string | null>(null);
  const [announcement, setAnnouncement] = useState('');
  const searchRef = useRef<CollegeSearchHandle>(null);
  const [summaryRef, summaryInView] = useInView<HTMLElement>();

  const colleges = useMemo<readonly College[]>(() => (state.custom.length ? [...COLLEGES, ...state.custom] : COLLEGES), [state.custom]);
  const byId = useMemo(() => new Map(colleges.map((c) => [c.id, c])), [colleges]);

  const items = useMemo<ListItem[]>(
    () =>
      state.plans.flatMap((plan) => {
        const college = byId.get(plan.collegeId);
        return college ? [{ college, plan, estimate: estimateChance(state.profile, college, plan) }] : [];
      }),
    [state.plans, state.profile, byId],
  );
  const outlook = useMemo(
    () => listOutlook(items.map((i) => i.estimate).filter((e): e is Estimate => e !== null), state.plans, byId),
    [items, state.plans, byId],
  );
  const inList = useMemo(() => new Set(state.plans.map((p) => p.collegeId)), [state.plans]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === '/' && !isTyping(e.target) && !e.metaKey && !e.ctrlKey) {
        e.preventDefault();
        searchRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  useEffect(() => {
    if (!freshId) return;
    const t = window.setTimeout(() => setFreshId(null), 1600);
    return () => window.clearTimeout(t);
  }, [freshId]);

  const add = useCallback(
    (c: College) => {
      dispatch({ type: 'add', collegeId: c.id });
      setFreshId(c.id);
      setAnnouncement(`Added ${c.name} to your list.`);
    },
    [dispatch],
  );

  const toggle = useCallback((id: string) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const focusGpa = () => {
    const el = document.getElementById('gpa');
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el?.focus({ preventScroll: true });
  };

  const hasGpa = state.profile.gpa != null;
  const mobileFigure = chanceParts(outlook.atLeastOne);

  return (
    <>
      <Header onHowItWorks={() => setHowOpen(true)} theme={theme.choice} onCycleTheme={theme.cycle} />
      <main className="page">
        <div className="intro">
          <h1>Your chances, college by college</h1>
          <p>
            Estimates for {formatCount(DATA_META.count)} U.S. colleges, built from federal admissions data. Change anything in
            your profile and every number updates.
          </p>
        </div>

        {state.example && (
          <div className="example-banner" role="note">
            <span className="example-tag">Example</span>
            <p>
              This is a sample student from Ohio. Edit the profile or the list to make it yours, or start with a blank page.
            </p>
            <div className="example-actions">
              <button type="button" className="btn btn-ghost" onClick={() => dispatch({ type: 'keepExample' })}>
                Keep editing this
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  dispatch({ type: 'startFresh' });
                  setExpanded(new Set());
                  window.setTimeout(focusGpa, 0);
                }}
              >
                Start fresh
              </button>
            </div>
          </div>
        )}

        <div className="layout">
          <ProfilePanel profile={state.profile} dispatch={dispatch} />
          <div className="results">
            <ListSummary
              ref={summaryRef}
              outlook={outlook}
              hasGpa={hasGpa}
              onPickCollege={() => searchRef.current?.focus()}
              onEnterGpa={focusGpa}
            />
            <CollegeSearch ref={searchRef} colleges={colleges} inList={inList} onAdd={add} onAddCustom={(name) => setCustomName(name)} />
            <CollegeList
              items={items}
              sort={state.sort}
              view={state.view}
              expanded={expanded}
              onToggle={toggle}
              dispatch={dispatch}
              freshId={freshId}
            />
            {items.length === 0 && (
              <div className="empty card">
                <p className="empty-title">Your list is empty</p>
                <p className="empty-sub">Search above, or start with a few colleges students often compare:</p>
                <div className="chips">
                  {SUGGESTIONS.map((id) => {
                    const c = byId.get(id)!;
                    return (
                      <button key={id} type="button" className="chip" onClick={() => add(c)}>
                        <PlusIcon size={14} />
                        {collegeName(c)}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      </main>

      <footer className="footer">
        <p>
          Data: U.S. Department of Education, IPEDS ({DATA_META.admissionsYear} admissions, {DATA_META.directoryYear}{' '}
          directory), plus hand-checked details for {DATA_META.curated} colleges. Estimates are for planning, not a promise of
          admission.{' '}
          <button type="button" className="link-btn" onClick={() => setHowOpen(true)}>
            How it works
          </button>
        </p>
      </footer>

      {hasGpa && items.length > 0 && (
        <div className="mobile-bar" data-visible={!summaryInView || undefined} aria-hidden={summaryInView}>
          <span className="mobile-bar-figure">
            {mobileFigure.prefix}
            {mobileFigure.value}%
          </span>
          <span className="mobile-bar-label">chance of at least one acceptance</span>
          <button
            type="button"
            className="btn btn-primary btn-sm"
            tabIndex={summaryInView ? -1 : 0}
            onClick={() => summaryRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
          >
            See list
          </button>
        </div>
      )}

      <Dialog open={howOpen} onClose={() => setHowOpen(false)} title="How it works" wide>
        <HowItWorks />
      </Dialog>
      <Dialog open={customName !== null} onClose={() => setCustomName(null)} title="Add a college by hand">
        <CustomCollegeForm
          initialName={customName ?? ''}
          onCancel={() => setCustomName(null)}
          onSave={(college) => {
            dispatch({ type: 'addCustom', college });
            setCustomName(null);
            setFreshId(college.id);
            setAnnouncement(`Added ${college.name} to your list.`);
          }}
        />
      </Dialog>
      <div className="visually-hidden" aria-live="polite">
        {announcement}
      </div>
    </>
  );
}

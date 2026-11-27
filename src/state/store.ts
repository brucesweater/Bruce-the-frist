import { useEffect, useReducer } from 'react';
import { idForSlug } from '../data/curated';
import type { College, Plan, Profile, Round } from '../model/types';

export type SortKey = 'chance' | 'name' | 'rate';
export type ViewMode = 'list' | 'table';

export interface AppState {
  profile: Profile;
  plans: Plan[];
  /** Colleges the user entered by hand. */
  custom: College[];
  /** True while the example student is loaded and untouched. */
  example: boolean;
  sort: SortKey;
  view: ViewMode;
}

export type Action =
  | { type: 'profile'; patch: Partial<Profile> }
  | { type: 'add'; collegeId: string }
  | { type: 'remove'; collegeId: string }
  | { type: 'plan'; collegeId: string; patch: Partial<Omit<Plan, 'collegeId'>> }
  | { type: 'addCustom'; college: College }
  | { type: 'sort'; sort: SortKey }
  | { type: 'view'; view: ViewMode }
  | { type: 'keepExample' }
  | { type: 'startFresh' };

export const BLANK_PROFILE: Profile = {
  gpa: null,
  testType: 'sat',
  sat: null,
  act: null,
  rigor: 2,
  activities: 2,
  essays: 1,
  recs: 1,
  residence: '',
  firstGen: false,
};

const EXAMPLE_PROFILE: Profile = {
  gpa: 3.86,
  testType: 'sat',
  sat: 1450,
  act: null,
  rigor: 3,
  activities: 2,
  essays: 2,
  recs: 1,
  residence: 'OH',
  firstGen: false,
};

const EXAMPLE_LIST: ReadonlyArray<readonly [slug: string, round: Round]> = [
  ['stanford', 'RD'],
  ['umich', 'EA'],
  ['wake-forest', 'RD'],
  ['tulane', 'RD'],
  ['cwru', 'ED'],
  ['uw-madison', 'RD'],
  ['uiuc', 'EA'],
  ['pitt', 'RD'],
  ['osu', 'EA'],
];

const newPlan = (collegeId: string, round: Round = 'RD'): Plan => ({ collegeId, round, legacy: false, athlete: false });

export function exampleState(): AppState {
  return {
    profile: EXAMPLE_PROFILE,
    plans: EXAMPLE_LIST.map(([slug, round]) => newPlan(idForSlug(slug), round)),
    custom: [],
    example: true,
    sort: 'chance',
    view: 'list',
  };
}

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'profile':
      return { ...state, profile: { ...state.profile, ...action.patch }, example: false };
    case 'add':
      if (state.plans.some((p) => p.collegeId === action.collegeId)) return state;
      return { ...state, plans: [...state.plans, newPlan(action.collegeId)], example: false };
    case 'remove':
      return {
        ...state,
        plans: state.plans.filter((p) => p.collegeId !== action.collegeId),
        custom: state.custom.filter((c) => c.id !== action.collegeId),
        example: false,
      };
    case 'plan':
      return {
        ...state,
        plans: state.plans.map((p) => (p.collegeId === action.collegeId ? { ...p, ...action.patch } : p)),
        example: false,
      };
    case 'addCustom':
      return {
        ...state,
        custom: [...state.custom, action.college],
        plans: [...state.plans, newPlan(action.college.id)],
        example: false,
      };
    case 'sort':
      return { ...state, sort: action.sort };
    case 'view':
      return { ...state, view: action.view };
    case 'keepExample':
      return { ...state, example: false };
    case 'startFresh':
      return { ...state, profile: BLANK_PROFILE, plans: [], custom: [], example: false };
  }
}

const STORAGE_KEY = 'admit-compass:v1';

/** Restores saved state, checking its shape so a stale or edited entry can't break the app. */
function load(): AppState {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return exampleState();
    const saved = JSON.parse(raw) as Partial<AppState>;
    if (!saved || typeof saved !== 'object' || !saved.profile || !Array.isArray(saved.plans)) return exampleState();
    const profile = { ...BLANK_PROFILE, ...saved.profile };
    const plans = saved.plans.filter((p): p is Plan => typeof p?.collegeId === 'string').map((p) => ({ ...newPlan(p.collegeId), ...p }));
    const custom = Array.isArray(saved.custom) ? saved.custom.filter((c) => typeof c?.id === 'string' && typeof c?.rate === 'number') : [];
    return {
      profile,
      plans,
      custom,
      example: false,
      sort: saved.sort === 'name' || saved.sort === 'rate' ? saved.sort : 'chance',
      view: saved.view === 'table' ? 'table' : 'list',
    };
  } catch {
    return exampleState();
  }
}

export function useAppState() {
  const [state, dispatch] = useReducer(reducer, undefined, load);

  useEffect(() => {
    if (state.example) return; // the example is a demo, not the user's data
    const id = window.setTimeout(() => {
      try {
        const { profile, plans, custom, sort, view } = state;
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ profile, plans, custom, sort, view }));
      } catch {
        // Storage can be unavailable (private windows, blocked site data); the app still works.
      }
    }, 250);
    return () => window.clearTimeout(id);
  }, [state]);

  return [state, dispatch] as const;
}

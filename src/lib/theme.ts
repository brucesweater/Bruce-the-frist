import { useCallback, useEffect, useState } from 'react';

export type ThemeChoice = 'system' | 'light' | 'dark';

const KEY = 'admit-compass:theme';
const root = () => document.documentElement;
// A host page may set data-theme itself; "system" restores whatever it set.
const initialAttribute = typeof document !== 'undefined' ? root().getAttribute('data-theme') : null;

function apply(choice: ThemeChoice) {
  if (choice === 'system') {
    if (initialAttribute) root().setAttribute('data-theme', initialAttribute);
    else root().removeAttribute('data-theme');
  } else root().setAttribute('data-theme', choice);
}

function read(): ThemeChoice {
  try {
    const v = window.localStorage.getItem(KEY);
    return v === 'light' || v === 'dark' ? v : 'system';
  } catch {
    return 'system';
  }
}

export function useTheme() {
  const [choice, setChoice] = useState<ThemeChoice>(read);
  useEffect(() => {
    apply(choice);
    try {
      if (choice === 'system') window.localStorage.removeItem(KEY);
      else window.localStorage.setItem(KEY, choice);
    } catch {
      // Not persisted; the choice still applies for this visit.
    }
  }, [choice]);
  const cycle = useCallback(
    () => setChoice((c) => (c === 'system' ? 'light' : c === 'light' ? 'dark' : 'system')),
    [],
  );
  return { choice, cycle };
}

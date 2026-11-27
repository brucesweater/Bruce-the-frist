import type { ThemeChoice } from '../lib/theme';
import { LogoMark, MoonIcon, SunIcon, SystemIcon } from './icons';

const THEME_LABEL: Record<ThemeChoice, string> = { system: 'System', light: 'Light', dark: 'Dark' };

export function Header({
  onHowItWorks,
  theme,
  onCycleTheme,
}: {
  onHowItWorks: () => void;
  theme: ThemeChoice;
  onCycleTheme: () => void;
}) {
  const Icon = theme === 'light' ? SunIcon : theme === 'dark' ? MoonIcon : SystemIcon;
  return (
    <header className="topbar">
      <div className="topbar-inner">
        <div className="brand">
          <LogoMark />
          <span className="brand-name">Admit Compass</span>
        </div>
        <nav className="topbar-actions" aria-label="App">
          <button type="button" className="btn btn-ghost" onClick={onHowItWorks}>
            How it works
          </button>
          <button
            type="button"
            className="icon-btn"
            onClick={onCycleTheme}
            aria-label={`Theme: ${THEME_LABEL[theme]}. Switch theme`}
            title={`Theme: ${THEME_LABEL[theme]}`}
          >
            <Icon />
          </button>
        </nav>
      </div>
    </header>
  );
}

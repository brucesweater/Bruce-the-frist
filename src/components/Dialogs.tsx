import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { DATA_META } from '../data/colleges';
import { STATES } from '../data/states';
import { formatCount } from '../lib/format';
import type { College, Control, TestPolicy } from '../model/types';
import { CloseIcon } from './icons';

export function Dialog({
  open,
  onClose,
  title,
  children,
  wide,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  wide?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog
      ref={ref}
      className={`dialog ${wide ? 'dialog-wide' : ''}`}
      aria-labelledby={`${title}-title`}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="dialog-body">
        <div className="dialog-head">
          <h2 id={`${title}-title`}>{title}</h2>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close">
            <CloseIcon />
          </button>
        </div>
        {open && children}
      </div>
    </dialog>
  );
}

export function HowItWorks() {
  return (
    <div className="prose">
      <p className="lede">
        Admit Compass estimates how a college might read your application, using the same kinds of numbers admissions offices
        publish. It is a well-informed guess, not a promise.
      </p>
      <ol className="steps">
        <li>
          <h3>Start from the admit rate</h3>
          <p>
            Each estimate begins with the share of applicants the college admits. Public universities use their in-state or
            out-of-state rate once you pick your home state.
          </p>
        </li>
        <li>
          <h3>Place your academics against the admitted class</h3>
          <p>
            Your GPA, SAT or ACT score and course rigor are compared with the middle 50% of enrolled students. At test-blind
            colleges scores are ignored; at test-optional ones you’re told when leaving a score off would help.
          </p>
        </li>
        <li>
          <h3>Weigh the rest of your application</h3>
          <p>
            Activities, essays and recommendations count for more at selective colleges, where nearly every applicant has
            strong grades.
          </p>
        </li>
        <li>
          <h3>Add timing and hooks</h3>
          <p>
            Early Decision, legacy status where it is still considered, recruited-athlete status and being the first in your
            family to attend college all shift the odds.
          </p>
        </li>
        <li>
          <h3>Show the uncertainty</h3>
          <p>
            The likely range covers the middle 80% of plausible chances. The chance of at least one acceptance accounts for
            the fact that your results are linked: if the calculator misjudges your application, it misjudges it everywhere.
          </p>
        </li>
      </ol>

      <h3>The math, briefly</h3>
      <p>
        Behind the scenes is a latent-index model. Every applicant gets a hidden score that mixes academics with everything
        else, and a college admits the top slice of its pool. The more selective the college, the less of that score comes
        from grades and tests. The calculator works out where you sit in the applicant pool, then how likely you are to clear
        the cut.
      </p>

      <h3>What it can’t see</h3>
      <ul>
        <li>What your essays and recommendations actually say, beyond your own rating</li>
        <li>Your intended major, which matters a lot at some universities</li>
        <li>Demonstrated interest, interviews and portfolios</li>
        <li>Financial need at colleges that consider it, and an institution’s priorities in a given year</li>
        <li>Race, which U.S. colleges can no longer consider (Supreme Court, 2023)</li>
      </ul>

      <h3>Where the data comes from</h3>
      <p>
        {formatCount(DATA_META.count)} colleges come from the U.S. Department of Education’s IPEDS database: admit rates
        and test score ranges from the {DATA_META.admissionsYear} admissions survey, and names, locations and enrollment
        from the {DATA_META.directoryYear} directory. For {DATA_META.curated} well-known colleges, average GPAs, early
        application rounds, legacy policies, current test policies and in-state admit rates were added by hand from Common
        Data Set reports and college announcements. Elsewhere, average GPA is estimated from test scores and admit rates.
      </p>
      <p className="fine-print">
        Policies change every year, so confirm details on each college’s website. Your profile is saved only in this browser.
      </p>
    </div>
  );
}

const pctToRate = (s: string) => {
  const n = Number(s);
  return Number.isFinite(n) && n > 0 && n <= 100 ? n / 100 : null;
};

/** A college entered by hand, for anything missing from the federal list. */
export function CustomCollegeForm({ initialName, onSave, onCancel }: { initialName: string; onSave: (c: College) => void; onCancel: () => void }) {
  const [name, setName] = useState(initialName);
  const [state, setState] = useState('');
  const [control, setControl] = useState<Control>('private');
  const [rate, setRate] = useState('');
  const [sat25, setSat25] = useState('');
  const [sat75, setSat75] = useState('');
  const [gpa, setGpa] = useState('');
  const [test, setTest] = useState<TestPolicy>('optional');
  const [error, setError] = useState<string | null>(null);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const r = pctToRate(rate);
    if (!name.trim()) return setError('Give the college a name.');
    if (r === null) return setError('Enter the admit rate as a percentage between 1 and 100.');
    const lo = Number(sat25);
    const hi = Number(sat75);
    const hasSat = sat25 !== '' || sat75 !== '';
    if (hasSat && !(lo >= 400 && hi <= 1600 && lo < hi)) return setError('SAT percentiles should run from 400 to 1600, with the 25th below the 75th.');
    const g = gpa === '' ? null : Number(gpa);
    if (g !== null && !(g >= 1 && g <= 4)) return setError('Average GPA should be between 1.0 and 4.0, unweighted.');
    onSave({
      id: `custom-${Date.now().toString(36)}`,
      name: name.trim(),
      city: 'Added by you',
      state: state || '—',
      control,
      level: 4,
      rate: r,
      sat: hasSat ? [lo, hi] : undefined,
      gpa: g ?? Math.min(3.97, Math.max(2.9, 3.72 - 0.077 * Math.log(Math.min(0.98, r) / (1 - Math.min(0.98, r))))),
      gpaEstimated: g === null || undefined,
      test,
      custom: true,
    });
  };

  return (
    <form className="form" onSubmit={submit} noValidate>
      <p className="lede">Use figures from the college’s website or its Common Data Set. Only the name and admit rate are required.</p>
      <label className="form-field form-field-wide">
        <span>College name</span>
        <input id="custom-name" value={name} onChange={(e) => setName(e.currentTarget.value)} autoFocus />
      </label>
      <label className="form-field">
        <span>Admit rate (%)</span>
        <input id="custom-rate" inputMode="decimal" value={rate} onChange={(e) => setRate(e.currentTarget.value)} placeholder="25" />
      </label>
      <label className="form-field">
        <span>Average GPA (unweighted)</span>
        <input id="custom-gpa" inputMode="decimal" value={gpa} onChange={(e) => setGpa(e.currentTarget.value)} placeholder="Optional" />
      </label>
      <label className="form-field">
        <span>SAT 25th percentile</span>
        <input id="custom-sat25" inputMode="numeric" value={sat25} onChange={(e) => setSat25(e.currentTarget.value)} placeholder="Optional" />
      </label>
      <label className="form-field">
        <span>SAT 75th percentile</span>
        <input id="custom-sat75" inputMode="numeric" value={sat75} onChange={(e) => setSat75(e.currentTarget.value)} placeholder="Optional" />
      </label>
      <label className="form-field">
        <span>Type</span>
        <span className="select-wrap">
          <select id="custom-control" value={control} onChange={(e) => setControl(e.currentTarget.value as Control)}>
            <option value="private">Private</option>
            <option value="public">Public</option>
          </select>
        </span>
      </label>
      <label className="form-field">
        <span>State</span>
        <span className="select-wrap">
          <select id="custom-state" value={state} onChange={(e) => setState(e.currentTarget.value)}>
            <option value="">Not sure</option>
            {STATES.map(([code, n]) => (
              <option key={code} value={code}>
                {n}
              </option>
            ))}
          </select>
        </span>
      </label>
      <label className="form-field form-field-wide">
        <span>SAT and ACT scores</span>
        <span className="select-wrap">
          <select id="custom-test" value={test} onChange={(e) => setTest(e.currentTarget.value as TestPolicy)}>
            <option value="optional">Optional</option>
            <option value="required">Required</option>
            <option value="blind">Not considered</option>
          </select>
        </span>
      </label>
      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
      <div className="form-actions">
        <button type="button" className="btn btn-ghost" onClick={onCancel}>
          Cancel
        </button>
        <button type="submit" className="btn btn-primary">
          Add to my list
        </button>
      </div>
    </form>
  );
}

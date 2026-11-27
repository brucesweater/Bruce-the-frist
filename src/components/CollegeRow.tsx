import type { Dispatch } from 'react';
import { collegeName, controlLabel, formatChance, formatCount, formatRange, formatRate, placeLabel, stateName, websiteUrl } from '../lib/format';
import { considersLegacy, roundsFor } from '../model/admission';
import { ROUND_LABELS, tierInfo } from '../model/scales';
import type { College, Estimate, Plan, Round } from '../model/types';
import type { Action } from '../state/store';
import { ChanceMeter, FactorBars, FitBar, TierPill } from './charts';
import { Segmented, Switch } from './controls';
import { ChevronIcon, ExternalIcon } from './icons';
import { NoteList } from './ListSummary';
import { Seal } from './Seal';

const TEST_POLICY = { required: 'Required', optional: 'Optional', blind: 'Not considered' } as const;

function admitText(c: College) {
  return c.openAdmission ? 'Open admission' : `${formatRate(c.rate)} admitted`;
}

function Badges({ college, plan, estimate }: { college: College; plan: Plan; estimate: Estimate | null }) {
  const badges: Array<{ label: string; kind?: 'warn' }> = [];
  if (plan.round !== 'RD') badges.push({ label: ROUND_LABELS[plan.round].short });
  if (plan.legacy && considersLegacy(college)) badges.push({ label: 'Legacy' });
  if (plan.athlete) badges.push({ label: 'Athlete' });
  if (estimate?.testMode === 'missing-required') badges.push({ label: 'Needs scores', kind: 'warn' });
  if (!badges.length) return null;
  return (
    <span className="badges">
      {badges.map((b) => (
        <span key={b.label} className="badge" data-kind={b.kind}>
          {b.label}
        </span>
      ))}
    </span>
  );
}

export function CollegeRow({
  college,
  plan,
  estimate,
  expanded,
  onToggle,
  dispatch,
  fresh,
}: {
  college: College;
  plan: Plan;
  estimate: Estimate | null;
  expanded: boolean;
  onToggle: () => void;
  dispatch: Dispatch<Action>;
  fresh?: boolean;
}) {
  const detailsId = `details-${college.id}`;
  const tier = estimate ? tierInfo(estimate.tier) : null;
  const capNote = estimate?.tierCap ? estimate.notes.find((n) => n.kind === 'info' && n.text.includes('applicants are admitted'))?.text : undefined;

  return (
    <li className="row" data-expanded={expanded || undefined} data-fresh={fresh || undefined} data-id={college.id}>
      <button type="button" className="row-head" aria-expanded={expanded} aria-controls={detailsId} onClick={onToggle}>
        <Seal college={college} />
        <span className="row-name">
          <span className="row-title">{college.name}</span>
          <span className="row-meta">
            {placeLabel(college)} · {controlLabel(college)} · {admitText(college)}
          </span>
        </span>
        <span className="row-meter">
          {estimate ? <ChanceMeter chance={estimate.chance} low={estimate.low} high={estimate.high} /> : <span className="meter-empty" />}
        </span>
        <span className="row-figure">
          <span className="row-pct">{estimate ? formatChance(estimate.chance) : '—'}</span>
          <span className="row-range">{estimate ? (college.openAdmission ? 'open' : formatRange(estimate.low, estimate.high)) : 'add GPA'}</span>
        </span>
        <span className="row-tier">
          {tier && <TierPill tier={tier.id} title={capNote} />}
          <Badges college={college} plan={plan} estimate={estimate} />
        </span>
        <span className="row-chevron" aria-hidden="true">
          <ChevronIcon />
        </span>
      </button>

      <div className="row-details" id={detailsId} inert={!expanded} aria-hidden={!expanded}>
        <div className="row-details-inner">
          <div className="details-content">
          {estimate ? <Details college={college} plan={plan} estimate={estimate} dispatch={dispatch} /> : <p className="details-empty">Enter your GPA to see this estimate.</p>}
          <div className="details-foot">
            {websiteUrl(college) && (
              <a className="btn btn-ghost" href={websiteUrl(college)!} target="_blank" rel="noreferrer">
                Visit website <ExternalIcon size={15} />
              </a>
            )}
            <button type="button" className="btn btn-ghost btn-danger" onClick={() => dispatch({ type: 'remove', collegeId: college.id })}>
              Remove from list
            </button>
          </div>
          </div>
        </div>
      </div>
    </li>
  );
}

function Details({ college, plan, estimate, dispatch }: { college: College; plan: Plan; estimate: Estimate; dispatch: Dispatch<Action> }) {
  const name = collegeName(college);
  const setPlan = (patch: Partial<Omit<Plan, 'collegeId'>>) => dispatch({ type: 'plan', collegeId: college.id, patch });
  const legacyOk = considersLegacy(college);
  const rounds = roundsFor(college);
  const g = estimate.gpaFit;
  const t = estimate.testFit;

  const residency =
    estimate.baseRateLabel === 'overall'
      ? null
      : `${formatRate(estimate.baseRate)} for ${estimate.baseRateLabel} applicants`;

  return (
    <>
      <div className="details-grid">
        <section className="details-block" aria-label={`Where you stand at ${name}`}>
          <h4 className="details-title">Where you stand</h4>
          {college.openAdmission ? (
            <p className="details-note">Everyone who applies with a high school diploma or equivalent is admitted.</p>
          ) : (
            <div className="fits">
              {g && (
                <FitBar
                  kind="GPA"
                  you={g.you}
                  low={g.low}
                  high={g.high}
                  mid={g.avg}
                  text={
                    <>
                      You <b className="mono">{g.you.toFixed(2)}</b> · average <span className="mono">{g.avg.toFixed(2)}</span>
                      {college.gpaEstimated && <span className="est"> (estimated)</span>}
                    </>
                  }
                />
              )}
              {t && (
                <FitBar
                  kind={t.kind}
                  you={t.you}
                  low={t.p25}
                  high={t.p75}
                  text={
                    <>
                      You <b className="mono">{t.you}</b>
                      {t.converted && <span className="est"> (converted)</span>} · middle 50%{' '}
                      <span className="mono">
                        {t.p25}–{t.p75}
                      </span>
                    </>
                  }
                />
              )}
              {!t && estimate.testMode === 'blind' && <p className="details-note">Test scores are not considered here.</p>}
              {!t && estimate.testMode === 'test-optional' && <p className="details-note">You’re applying without test scores.</p>}
            </div>
          )}
          <dl className="facts">
            <div>
              <dt>Admit rate</dt>
              <dd>
                {college.openAdmission ? 'Open admission' : `${formatRate(college.rate)} overall`}
                {residency && <span className="facts-sub">{residency}</span>}
              </dd>
            </div>
            {!college.openAdmission && (
              <div>
                <dt>SAT or ACT</dt>
                <dd>{TEST_POLICY[college.test]}</dd>
              </div>
            )}
            {college.size !== undefined && (
              <div>
                <dt>Undergraduates</dt>
                <dd className="tabular">{formatCount(college.size)}</dd>
              </div>
            )}
            <div>
              <dt>Location</dt>
              <dd>
                {college.city}, {stateName(college.state)}
              </dd>
            </div>
            {college.tags && (
              <div>
                <dt>Also</dt>
                <dd>{college.tags.join(' · ')}</dd>
              </div>
            )}
          </dl>
        </section>

        {estimate.factors.length > 0 && (
          <section className="details-block" aria-label={`What moves your odds at ${name}`}>
            <h4 className="details-title">What moves your odds</h4>
            <FactorBars factors={estimate.factors} />
            <p className="details-note">Each bar compares you with a typical applicant here, in percentage points.</p>
          </section>
        )}
      </div>

      {!college.openAdmission && (
        <section className="details-plan" aria-label={`Your application to ${name}`}>
          <h4 className="details-title">Your application</h4>
          <div className="plan-controls">
            <Segmented<Round>
              id={`round-${college.id}`}
              label="Round"
              size="sm"
              value={plan.round}
              onChange={(round) => setPlan({ round })}
              options={rounds.map((r) => ({ value: r, label: ROUND_LABELS[r].short, title: ROUND_LABELS[r].long }))}
            />
            <Switch
              id={`legacy-${college.id}`}
              checked={plan.legacy && legacyOk}
              disabled={!legacyOk}
              onChange={(legacy) => setPlan({ legacy })}
              label="Legacy"
              hint={legacyOk ? 'A parent graduated from here.' : `${name} doesn’t consider legacy status.`}
            />
            <Switch
              id={`athlete-${college.id}`}
              checked={plan.athlete}
              onChange={(athlete) => setPlan({ athlete })}
              label="Recruited athlete"
              hint="A coach is backing your application."
            />
          </div>
          {!college.rounds && <p className="details-note">We don’t have this college’s early deadlines. Pick the round you’ll actually use.</p>}
        </section>
      )}

      <NoteList notes={estimate.notes} />
    </>
  );
}

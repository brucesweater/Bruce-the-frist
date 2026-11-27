import type { Dispatch } from 'react';
import { INTERNATIONAL, STATES } from '../data/states';
import { roundedActFor, roundedSatFor } from '../model/concordance';
import { ACTIVITIES, ESSAYS, RECOMMENDATIONS, RIGOR } from '../model/scales';
import type { Profile, TestType } from '../model/types';
import type { Action } from '../state/store';
import { LevelScale, NumberSlider, Segmented, Switch } from './controls';

export function ProfilePanel({ profile, dispatch }: { profile: Profile; dispatch: Dispatch<Action> }) {
  const set = (patch: Partial<Profile>) => dispatch({ type: 'profile', patch });

  const testHint =
    profile.testType === 'sat'
      ? profile.sat != null
        ? `About the same as an ACT ${roundedActFor(profile.sat)}.`
        : 'Your best total score. Leave it blank if you haven’t tested yet.'
      : profile.testType === 'act'
        ? profile.act != null
          ? `About the same as an SAT ${roundedSatFor(profile.act)}.`
          : 'Your best composite score.'
        : null;

  return (
    <aside className="panel profile" aria-labelledby="profile-title">
      <div className="panel-head">
        <h2 id="profile-title">Your profile</h2>
        <p className="panel-sub">Every estimate updates as you change these.</p>
      </div>

      <section className="profile-section" aria-labelledby="sec-academics">
        <h3 className="eyebrow" id="sec-academics">
          Academics
        </h3>
        <NumberSlider
          id="gpa"
          label="GPA"
          suffix={<span className="field-tag">Unweighted · 4.0 scale</span>}
          value={profile.gpa}
          min={1}
          max={4}
          step={0.01}
          decimals={2}
          placeholder="3.75"
          onChange={(gpa) => set({ gpa })}
          hint={profile.gpa == null ? 'Enter your GPA to see your chances.' : 'Without extra points for honors or AP classes.'}
          rangeMessage="Use your unweighted GPA, from 1.00 to 4.00."
        />

        <div className="field test-field">
          <Segmented<TestType>
            id="test-type"
            label="Test scores"
            value={profile.testType}
            onChange={(testType) => set({ testType })}
            options={[
              { value: 'sat', label: 'SAT' },
              { value: 'act', label: 'ACT' },
              { value: 'none', label: 'No scores' },
            ]}
          />
          {profile.testType === 'sat' && (
            <NumberSlider
              id="sat"
              label="SAT total"
              value={profile.sat}
              min={400}
              max={1600}
              step={10}
              placeholder="1350"
              onChange={(sat) => set({ sat })}
              hint={testHint}
              rangeMessage="SAT totals run from 400 to 1600."
            />
          )}
          {profile.testType === 'act' && (
            <NumberSlider
              id="act"
              label="ACT composite"
              value={profile.act}
              min={1}
              max={36}
              step={1}
              placeholder="30"
              onChange={(act) => set({ act })}
              hint={testHint}
              rangeMessage="ACT composites run from 1 to 36."
            />
          )}
          {profile.testType === 'none' && (
            <p className="field-hint">
              Fine at test-optional colleges. Colleges that require scores are flagged in your list.
            </p>
          )}
        </div>

        <LevelScale id="rigor" label="Course rigor" options={RIGOR} value={profile.rigor} onChange={(rigor) => set({ rigor })} />
      </section>

      <section className="profile-section" aria-labelledby="sec-beyond">
        <h3 className="eyebrow" id="sec-beyond">
          Beyond grades
        </h3>
        <LevelScale
          id="activities"
          label="Activities and awards"
          options={ACTIVITIES}
          value={profile.activities}
          onChange={(activities) => set({ activities })}
        />
        <LevelScale id="essays" label="Essays" options={ESSAYS} value={profile.essays} onChange={(essays) => set({ essays })} />
        <LevelScale
          id="recs"
          label="Recommendations"
          options={RECOMMENDATIONS}
          value={profile.recs}
          onChange={(recs) => set({ recs })}
        />
      </section>

      <section className="profile-section" aria-labelledby="sec-about">
        <h3 className="eyebrow" id="sec-about">
          About you
        </h3>
        <div className="field">
          <div className="field-head">
            <label className="field-label" htmlFor="residence">
              Home state
            </label>
          </div>
          <div className="select-wrap">
            <select id="residence" value={profile.residence} onChange={(e) => set({ residence: e.currentTarget.value })}>
              <option value="">Choose a state</option>
              {STATES.map(([code, name]) => (
                <option key={code} value={code}>
                  {name}
                </option>
              ))}
              <option value={INTERNATIONAL}>Outside the U.S.</option>
            </select>
          </div>
          <p className="field-hint">Public universities admit in-state students at higher rates.</p>
        </div>
        <Switch
          id="first-gen"
          checked={profile.firstGen}
          onChange={(firstGen) => set({ firstGen })}
          label="First-generation college student"
          hint="Neither parent has a bachelor’s degree."
        />
      </section>
    </aside>
  );
}

import { useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import type { ScaleOption } from '../model/scales';

/** Arrow-key handling shared by the radio-group style controls. */
function useRovingKeys(count: number, value: number, onChange: (i: number) => void) {
  const refs = useRef<Array<HTMLButtonElement | null>>([]);
  const onKeyDown = (e: KeyboardEvent) => {
    let next = value;
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') next = Math.min(count - 1, value + 1);
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') next = Math.max(0, value - 1);
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = count - 1;
    else return;
    e.preventDefault();
    onChange(next);
    refs.current[next]?.focus();
  };
  return { refs, onKeyDown };
}

/**
 * A rating picked from rising bars, like a signal meter: the more bars,
 * the stronger that part of the application.
 */
export function LevelScale({
  id,
  label,
  options,
  value,
  onChange,
}: {
  id: string;
  label: string;
  options: readonly ScaleOption[];
  value: number;
  onChange: (value: number) => void;
}) {
  const labelId = `${id}-label`;
  const descId = `${id}-desc`;
  const { refs, onKeyDown } = useRovingKeys(options.length, value, onChange);
  const selected = options[value];
  return (
    <div className="field level-field">
      <div className="field-head">
        <span className="field-label" id={labelId}>
          {label}
        </span>
        <span className="level-value" aria-hidden="true">
          {selected.label}
        </span>
      </div>
      <div className="level-row">
        <div className="level-bars" role="radiogroup" aria-labelledby={labelId} aria-describedby={descId} onKeyDown={onKeyDown}>
          {options.map((o, i) => (
            <button
              key={o.label}
              ref={(el) => {
                refs.current[i] = el;
              }}
              type="button"
              role="radio"
              id={`${id}-${i}`}
              aria-checked={i === value}
              aria-label={o.label}
              tabIndex={i === value ? 0 : -1}
              className="level-bar"
              data-on={i <= value || undefined}
              style={{ ['--h' as string]: `${30 + (70 * i) / (options.length - 1)}%` }}
              onClick={() => onChange(i)}
              title={o.label}
            >
              <span className="level-bar-fill" />
            </button>
          ))}
        </div>
        <p className="field-hint level-desc" id={descId}>
          {selected.description}
        </p>
      </div>
    </div>
  );
}

export function Segmented<T extends string>({
  id,
  label,
  options,
  value,
  onChange,
  hideLabel,
  size = 'md',
}: {
  id: string;
  label: string;
  options: ReadonlyArray<{ value: T; label: ReactNode; title?: string }>;
  value: T;
  onChange: (value: T) => void;
  hideLabel?: boolean;
  size?: 'sm' | 'md';
}) {
  const index = Math.max(0, options.findIndex((o) => o.value === value));
  const { refs, onKeyDown } = useRovingKeys(options.length, index, (i) => onChange(options[i].value));
  const labelId = `${id}-label`;
  return (
    <div className={`segmented segmented-${size}`}>
      <span id={labelId} className={hideLabel ? 'visually-hidden' : 'field-label'}>
        {label}
      </span>
      <div className="segmented-track" role="radiogroup" aria-labelledby={labelId} onKeyDown={onKeyDown}>
        {options.map((o, i) => (
          <button
            key={o.value}
            ref={(el) => {
              refs.current[i] = el;
            }}
            type="button"
            role="radio"
            id={`${id}-${o.value}`}
            aria-checked={i === index}
            tabIndex={i === index ? 0 : -1}
            className="segmented-option"
            title={o.title}
            onClick={() => onChange(o.value)}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}

export function Switch({
  id,
  checked,
  onChange,
  label,
  hint,
  disabled,
}: {
  id: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: ReactNode;
  hint?: ReactNode;
  disabled?: boolean;
}) {
  const hintId = useId();
  return (
    <div className="switch-field" data-disabled={disabled || undefined}>
      <button
        type="button"
        role="switch"
        id={id}
        aria-checked={checked}
        aria-describedby={hint ? hintId : undefined}
        disabled={disabled}
        className="switch"
        onClick={() => onChange(!checked)}
      >
        <span className="switch-thumb" />
      </button>
      <span className="switch-text">
        <label htmlFor={id} className="switch-label">
          {label}
        </label>
        {hint && (
          <span id={hintId} className="field-hint">
            {hint}
          </span>
        )}
      </span>
    </div>
  );
}

/**
 * A number with a matching slider. While the box has focus the student's own
 * text is kept as typed; any valid number inside the range updates results
 * immediately, and the box is tidied (or reverted) on blur.
 */
export function NumberSlider({
  id,
  label,
  hint,
  value,
  min,
  max,
  step,
  decimals = 0,
  onChange,
  placeholder,
  rangeMessage,
  suffix,
}: {
  id: string;
  label: string;
  hint?: ReactNode;
  value: number | null;
  min: number;
  max: number;
  step: number;
  decimals?: number;
  onChange: (value: number | null) => void;
  placeholder?: string;
  /** Shown when the typed number is outside the range. */
  rangeMessage?: string;
  suffix?: ReactNode;
}) {
  const hintId = `${id}-hint`;
  const shown = value == null ? '' : value.toFixed(decimals);
  const [draft, setDraft] = useState(shown);
  const [focused, setFocused] = useState(false);
  const parsed = draft.trim() === '' ? null : Number(draft.trim());
  const outOfRange = focused && parsed !== null && (!Number.isFinite(parsed) || parsed < min || parsed > max);
  const error = outOfRange ? (rangeMessage ?? `Enter a number from ${min} to ${max}.`) : null;
  const sliderValue = value ?? (min + max) / 2;
  const fill = ((Math.min(max, Math.max(min, sliderValue)) - min) / (max - min)) * 100;
  return (
    <div className="field number-field">
      <div className="field-head">
        <label className="field-label" htmlFor={id}>
          {label}
        </label>
        {suffix}
      </div>
      <div className="number-row">
        <input
          id={id}
          className="number-input mono"
          inputMode={decimals ? 'decimal' : 'numeric'}
          autoComplete="off"
          placeholder={placeholder}
          aria-describedby={hint || error ? hintId : undefined}
          aria-invalid={error ? true : undefined}
          value={focused ? draft : shown}
          onFocus={() => {
            setDraft(shown);
            setFocused(true);
          }}
          onBlur={() => {
            setFocused(false);
            if (draft.trim() === '') onChange(null);
          }}
          onChange={(e) => {
            const text = e.currentTarget.value;
            setDraft(text);
            const n = Number(text.trim());
            if (text.trim() !== '' && Number.isFinite(n) && n >= min && n <= max) onChange(Number(n.toFixed(decimals)));
          }}
          onKeyDown={(e) => {
            if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
              e.preventDefault();
              const base = value ?? (min + max) / 2;
              const next = Number(Math.min(max, Math.max(min, base + (e.key === 'ArrowUp' ? step : -step))).toFixed(decimals));
              setDraft(next.toFixed(decimals));
              onChange(next);
            } else if (e.key === 'Enter') e.currentTarget.blur();
          }}
        />
        <input
          type="range"
          className="slider"
          aria-label={`${label} slider`}
          min={min}
          max={max}
          step={step}
          value={sliderValue}
          data-empty={value == null || undefined}
          style={{ ['--fill' as string]: `${fill}%` }}
          onChange={(e) => onChange(Number(Number(e.currentTarget.value).toFixed(decimals)))}
        />
      </div>
      {(hint || error) && (
        <p id={hintId} className={error ? 'field-hint field-error' : 'field-hint'} aria-live={error ? 'polite' : undefined}>
          {error ?? hint}
        </p>
      )}
    </div>
  );
}

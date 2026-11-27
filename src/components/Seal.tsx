import { monogram } from '../lib/format';
import type { College } from '../model/types';

/** A small university-seal style monogram: two rings and the college's initials. */
export function Seal({ college, size = 'md' }: { college: College; size?: 'sm' | 'md' }) {
  const letters = monogram(college);
  return (
    <span className={`seal seal-${size}`} data-len={letters.length} aria-hidden="true">
      {letters}
    </span>
  );
}

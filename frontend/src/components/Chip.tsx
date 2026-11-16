import type { ReactNode } from 'react';
import { Icon } from './Icon';

// A ChoiceChip: one of several filters, the selected one shaded and ticked.
export function Chip({ selected, onClick, children }: { selected: boolean; onClick(): void; children: ReactNode }) {
  return (
    <button type="button" className="chip" aria-pressed={selected} onClick={onClick}>
      {selected && <Icon name="check" size={18} />}
      {children}
    </button>
  );
}

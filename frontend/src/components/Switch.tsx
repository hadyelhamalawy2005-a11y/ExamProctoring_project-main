import { useI18n } from '../i18n/LanguageContext';

interface SwitchProps {
  id: string;
  label: string;
  hint?: string;
  checked: boolean;
  onChange(checked: boolean): void;
}

// An On / Off toggle. The state is shown three ways (position, colour and the words On / Off), so colour is never the
// only signal. It is a real button with role="switch", so it works with the keyboard and screen readers.
export function Switch({ id, label, hint, checked, onChange }: SwitchProps) {
  const { t } = useI18n();
  return (
    <div className="switch-field">
      <div className="switch-row">
        <span id={`${id}-label`} className="switch-label">
          {label}
        </span>
        <button
          type="button"
          id={id}
          role="switch"
          aria-checked={checked}
          aria-labelledby={`${id}-label`}
          aria-describedby={hint ? `${id}-hint` : undefined}
          className="switch"
          onClick={() => onChange(!checked)}
        >
          <span className="switch-track" aria-hidden="true">
            <span className="switch-thumb" />
          </span>
          <span className="switch-state">{checked ? t('common.on') : t('common.off')}</span>
        </button>
      </div>
      {hint && (
        <p id={`${id}-hint`} className="field-hint">
          {hint}
        </p>
      )}
    </div>
  );
}

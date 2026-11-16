import { useState, type ReactNode } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { resolveMsg, type Msg } from '../i18n/serverMessages';
import { describedBy } from './FormField';
import { Icon } from './Icon';

interface FloatingFieldProps {
  id: string;
  label: string;
  type: 'email' | 'password' | 'text';
  value: string;
  onChange(value: string): void;
  error?: Msg;
  autoComplete?: string;
  disabled?: boolean;
  // Email and password text stays left-to-right inside a right-to-left page.
  ltr?: boolean;
  trailing?: ReactNode;
}

// An outlined text field whose label sits inside the box and floats onto the border once the field is focused or filled
// (the look of the app's mobile sign-in screen). Password fields get a show/hide button. The label is a real <label>, and
// errors are linked with aria-describedby, so it reads the same to a screen reader as the plain fields.
export function FloatingField({ id, label, type, value, onChange, error, autoComplete, disabled, ltr, trailing }: FloatingFieldProps) {
  const i18n = useI18n();
  const { t } = i18n;
  const [revealed, setRevealed] = useState(false);
  const isPassword = type === 'password';

  return (
    <div className={`float-field ${error ? 'float-field-invalid' : ''}`}>
      <div className="float-box">
        <input
          id={id}
          className="float-input"
          type={isPassword && revealed ? 'text' : type}
          dir={ltr ? 'ltr' : undefined}
          placeholder=" "
          value={value}
          autoComplete={autoComplete}
          disabled={disabled}
          onChange={(event) => onChange(event.target.value)}
          aria-invalid={Boolean(error)}
          aria-describedby={describedBy(id, error)}
        />
        <label className="float-label" htmlFor={id}>
          {label}
        </label>
        {isPassword && (
          <button
            type="button"
            className="float-toggle"
            onClick={() => setRevealed((previous) => !previous)}
            aria-label={revealed ? t('login.hidePassword') : t('login.showPassword')}
            aria-pressed={revealed}
            disabled={disabled}
          >
            <Icon name={revealed ? 'eyeOff' : 'eye'} size={22} />
          </button>
        )}
        {trailing}
      </div>
      {error && (
        <p className="float-error" id={`${id}-error`}>
          {resolveMsg(error, i18n)}
        </p>
      )}
    </div>
  );
}

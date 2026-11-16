import { useState, type ReactNode } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { resolveMsg, type Msg } from '../i18n/serverMessages';
import { describedBy } from './FormField';

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
            <svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true" focusable="false">
              {revealed ? (
                <path
                  fill="currentColor"
                  d="M12 6.5c3.79 0 7.17 2.13 8.82 5.5-.59 1.22-1.42 2.27-2.41 3.12l1.41 1.41c1.39-1.23 2.49-2.77 3.18-4.53C21.27 7.11 17 4 12 4c-1.27 0-2.49.2-3.64.57l1.65 1.65c.64-.13 1.29-.22 1.99-.22zm-1.07 1.14L13 9.71c.57.25 1.03.71 1.28 1.28l2.07 2.07c.08-.34.14-.7.14-1.07C16.5 9.01 14.48 7 12 7c-.37 0-.72.05-1.07.14zM2.01 3.87l2.68 2.68C3.06 7.83 1.77 9.53 1 11.5 2.73 15.89 7 19 12 19c1.52 0 2.98-.29 4.32-.82l3.42 3.42 1.41-1.41L3.42 2.45 2.01 3.87zm7.5 7.5l2.61 2.61c-.04.01-.08.02-.12.02-1.38 0-2.5-1.12-2.5-2.5 0-.05.01-.08.01-.13zm-3.4-3.4l1.75 1.75c-.23.55-.36 1.15-.36 1.78 0 2.48 2.02 4.5 4.5 4.5.63 0 1.23-.13 1.77-.36l.98.98c-.88.24-1.8.38-2.75.38-3.79 0-7.17-2.13-8.82-5.5.7-1.43 1.72-2.61 2.93-3.53z"
                />
              ) : (
                <path
                  fill="currentColor"
                  d="M12 6.5c3.79 0 7.17 2.13 8.82 5.5-1.65 3.37-5.02 5.5-8.82 5.5S4.83 15.37 3.18 12C4.83 8.63 8.21 6.5 12 6.5m0-2C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zm0 5c1.38 0 2.5 1.12 2.5 2.5s-1.12 2.5-2.5 2.5-2.5-1.12-2.5-2.5 1.12-2.5 2.5-2.5m0-2c-2.48 0-4.5 2.02-4.5 4.5s2.02 4.5 4.5 4.5 4.5-2.02 4.5-4.5-2.02-4.5-4.5-4.5z"
                />
              )}
            </svg>
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

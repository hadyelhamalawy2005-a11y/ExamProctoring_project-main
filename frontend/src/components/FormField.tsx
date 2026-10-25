import type { ReactNode } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { resolveMsg, type Msg } from '../i18n/serverMessages';

interface FormFieldProps {
  id: string;
  label: string;
  error?: Msg;
  hint?: ReactNode;
  children: ReactNode;
}

// Label, control, hint and error message, linked for screen readers through the control's id.
export function FormField({ id, label, error, hint, children }: FormFieldProps) {
  const i18n = useI18n();
  return (
    <div className={`field ${error ? 'field-invalid' : ''}`}>
      <label htmlFor={id}>{label}</label>
      {children}
      {hint && !error && (
        <p className="field-hint" id={`${id}-hint`}>
          {hint}
        </p>
      )}
      {error && (
        <p className="field-error" id={`${id}-error`}>
          {resolveMsg(error, i18n)}
        </p>
      )}
    </div>
  );
}

// aria-describedby value for the control inside a FormField.
export function describedBy(id: string, error?: Msg, hasHint = false): string | undefined {
  if (error) return `${id}-error`;
  return hasHint ? `${id}-hint` : undefined;
}

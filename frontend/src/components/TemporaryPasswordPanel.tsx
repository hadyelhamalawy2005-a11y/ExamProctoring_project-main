import { useState } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { Alert } from './Feedback';

interface TemporaryPasswordPanelProps {
  password: string;
  expiresAt: string;
  onDone(): void; // the admin has handed the password over: the panel (and the password in memory) goes away
}

// The one place a temporary password is shown. It exists only in the page's memory: it is never written to storage, to
// the URL or to the console, and it disappears when the admin closes the panel or leaves the page. The backend returns
// it once and keeps only a hash.
export function TemporaryPasswordPanel({ password, expiresAt, onDone }: TemporaryPasswordPanelProps) {
  const { t, formatDateTime } = useI18n();
  const [copy, setCopy] = useState<'idle' | 'copied' | 'failed'>('idle');

  const copyPassword = async () => {
    try {
      await navigator.clipboard.writeText(password);
      setCopy('copied');
    } catch {
      setCopy('failed');
    }
  };

  return (
    <section className="card temp-password" aria-labelledby="temp-password-heading">
      <h2 id="temp-password-heading">{t('admin.tp.resultTitle')}</h2>
      <Alert tone="warning">{t('admin.tp.shownOnce')}</Alert>
      <div className="temp-password-row">
        <output className="temp-password-value" dir="ltr" data-testid="temp-password">
          {password}
        </output>
        <button type="button" className="button button-secondary" onClick={() => void copyPassword()}>
          {copy === 'copied' ? t('admin.tp.copied') : t('admin.tp.copy')}
        </button>
      </div>
      {copy === 'failed' && <p className="field-error">{t('admin.tp.copyFailed')}</p>}
      <p className="muted">{t('admin.tp.expires', { when: formatDateTime(expiresAt) })}</p>
      <div className="form-actions">
        <button type="button" className="button" onClick={onDone}>
          {t('admin.tp.done')}
        </button>
      </div>
    </section>
  );
}

import type { ReactNode } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { Icon, type IconName } from './Icon';

export function Spinner({ label }: { label?: string }) {
  const { t } = useI18n();
  return (
    <span className="spinner-wrap" role="status" aria-live="polite">
      <span className="spinner" aria-hidden="true" />
      <span>{label ?? t('common.loading')}</span>
    </span>
  );
}

export function PageLoader({ label }: { label?: string }) {
  return (
    <div className="page-loader">
      <Spinner label={label} />
    </div>
  );
}

type AlertTone = 'error' | 'success' | 'info' | 'warning';

// The banner icon carries the meaning too, not only the colour (AppBanner).
const ALERT_ICONS: Record<AlertTone, IconName> = { error: 'error', success: 'success', info: 'info', warning: 'warning' };

export function Alert({ tone, children, onDismiss }: { tone: AlertTone; children: ReactNode; onDismiss?: () => void }) {
  const { t } = useI18n();
  return (
    <div className={`alert alert-${tone}`} role={tone === 'error' ? 'alert' : 'status'}>
      <Icon name={ALERT_ICONS[tone]} className="alert-icon" />
      <div className="alert-body">{children}</div>
      {onDismiss && (
        <button type="button" className="alert-dismiss" onClick={onDismiss} aria-label={t('common.dismiss')}>
          ×
        </button>
      )}
    </div>
  );
}

export function EmptyState({ title, children, icon = 'inbox' }: { title: string; children?: ReactNode; icon?: IconName }) {
  return (
    <div className="empty-state">
      <Icon name={icon} size={48} />
      <h3>{title}</h3>
      {children}
    </div>
  );
}

import type { ReactNode } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';
import { Logo } from './Logo';

// The frame of every page shown before sign-in (sign in, register, forgot password, change password, errors): a burgundy
// brand panel with the logo and the brand line on wide screens, and the page's own card beside it. On a phone the brand
// panel shrinks to a header strip so the form stays the first thing on screen.
export function AuthShell({ children, toolbar = true }: { children: ReactNode; toolbar?: boolean }) {
  const { t } = useI18n();
  return (
    <div className="auth-page">
      <aside className="auth-brand">
        <Logo tone="reversed" height={36} className="auth-brand-logo" label="Examora" />
        <p className="auth-brand-line">
          <span>{t('brand.line1')}</span>
          <span>{t('brand.line2')}</span>
        </p>
      </aside>
      <main className="auth-main">
        {toolbar && (
          <div className="auth-toolbar">
            <LanguageToggle />
          </div>
        )}
        <div className="auth-slot">{children}</div>
      </main>
    </div>
  );
}

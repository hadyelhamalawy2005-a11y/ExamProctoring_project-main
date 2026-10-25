import { useI18n } from './LanguageContext';

// Each language is named in its own language, whatever the current language is.
export function LanguageToggle() {
  const { lang, setLang, t } = useI18n();
  return (
    <div className="lang-toggle" role="group" aria-label={t('lang.label')}>
      <button type="button" lang="ar" aria-pressed={lang === 'ar'} onClick={() => setLang('ar')}>
        العربية
      </button>
      <button type="button" lang="en" aria-pressed={lang === 'en'} onClick={() => setLang('en')}>
        English
      </button>
    </div>
  );
}

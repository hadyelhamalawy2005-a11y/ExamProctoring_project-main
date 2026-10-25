import { createContext, useCallback, useContext, useLayoutEffect, useMemo, useState, type ReactNode } from 'react';
import { createI18n, DEFAULT_LANG, directionOf, englishI18n, type I18n, type Lang } from './translate';

// Only the language code is stored in localStorage (no tokens, no personal data).
export const LANGUAGE_STORAGE_KEY = 'lang';

function readStoredLanguage(): Lang {
  try {
    const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    if (stored === 'ar' || stored === 'en') return stored;
  } catch {
    // storage blocked: fall back to the default
  }
  return DEFAULT_LANG;
}

const LanguageContext = createContext<I18n>(englishI18n);

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(readStoredLanguage);

  // <html lang dir> follows the language before the browser paints.
  useLayoutEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = directionOf(lang);
  }, [lang]);

  const setLang = useCallback((next: Lang) => {
    setLangState(next);
    try {
      window.localStorage.setItem(LANGUAGE_STORAGE_KEY, next);
    } catch {
      // the choice then only lasts until the page is reloaded
    }
  }, []);

  const value = useMemo(() => createI18n(lang, setLang), [lang, setLang]);
  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useI18n(): I18n {
  return useContext(LanguageContext);
}

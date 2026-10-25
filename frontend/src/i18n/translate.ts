import { ar } from './ar';
import { en, type TranslationKey } from './en';

export type Lang = 'ar' | 'en';
export type Dir = 'rtl' | 'ltr';
export type Params = Record<string, string | number>;
export type Translator = (key: TranslationKey, params?: Params) => string;

export const LANGUAGES: Lang[] = ['ar', 'en'];
export const DEFAULT_LANG: Lang = 'ar';

export const dictionaries: Record<Lang, Record<TranslationKey, string>> = { en, ar };

export const directionOf = (lang: Lang): Dir => (lang === 'ar' ? 'rtl' : 'ltr');

// "ar-u-nu-latn": Arabic month names with Western digits, because the inputs (dates, marks, duration) and the backend use
// Western digits.
const LOCALES: Record<Lang, string> = { ar: 'ar-u-nu-latn', en: 'en' };

export interface I18n {
  lang: Lang;
  dir: Dir;
  t: Translator;
  setLang(lang: Lang): void;
  formatDateTime(iso: string | null): string;
  formatNumber(value: number, options?: Intl.NumberFormatOptions): string;
}

export function createTranslator(lang: Lang): Translator {
  const dictionary = dictionaries[lang];
  return (key, params) => {
    const text = dictionary[key];
    if (!params) return text;
    return text.replace(/\{(\w+)\}/g, (placeholder, name: string) => (name in params ? String(params[name]) : placeholder));
  };
}

export function formatDateTime(iso: string | null, lang: Lang): string {
  if (!iso) return '—';
  return new Intl.DateTimeFormat(LOCALES[lang], { day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
}

export function formatNumber(value: number, lang: Lang, options?: Intl.NumberFormatOptions): string {
  return new Intl.NumberFormat(LOCALES[lang], options).format(value);
}

export function createI18n(lang: Lang, setLang: (lang: Lang) => void): I18n {
  return {
    lang,
    dir: directionOf(lang),
    t: createTranslator(lang),
    setLang,
    formatDateTime: (iso) => formatDateTime(iso, lang),
    formatNumber: (value, options) => formatNumber(value, lang, options),
  };
}

// Used when no <LanguageProvider> is present (plain unit tests and helper functions): English, no persistence.
export const englishI18n: I18n = createI18n('en', () => undefined);

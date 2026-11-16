import { lazy, Suspense, useEffect, useState } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import { readPreferences, writePreferences } from '../local/examExtras';
import { CODE_LANGUAGES, type CodeQuestion, type EditorPreferences } from '../types/code';
import { Spinner } from './Feedback';

const CodeEditor = lazy(() => import('./CodeEditor'));

interface CodeAnswerPanelProps {
  examId: string;
  question: CodeQuestion;
  value: string;
  onChange(value: string): void;
  idPrefix: string;
}

// What a student sees for a code question: a toolbar (language and a small settings menu) above the editor. Only the
// languages, modes and tab sizes the teacher allowed are offered, and the student's choices are kept for the session.
// Autocomplete is the teacher's decision, so it is shown as a state, not a switch.
export function CodeAnswerPanel({ examId, question, value, onChange, idPrefix }: CodeAnswerPanelProps) {
  const { t } = useI18n();
  const [prefs, setPrefs] = useState<EditorPreferences>(() => {
    const saved = readPreferences(examId, question.id);
    return {
      language: saved.language && question.languages.includes(saved.language) ? saved.language : question.defaultLanguage,
      mode: saved.mode && question.editorModes.includes(saved.mode) ? saved.mode : question.defaultMode,
      tabSize: saved.tabSize && question.tabSizes.includes(saved.tabSize) ? saved.tabSize : question.defaultTabSize,
    };
  });

  useEffect(() => writePreferences(examId, question.id, prefs), [examId, question.id, prefs]);

  const languages = CODE_LANGUAGES.filter((language) => question.languages.includes(language.id));

  return (
    <div className="code-panel">
      <div className="code-toolbar">
        <label className="code-toolbar-field" htmlFor={`${idPrefix}-language`}>
          <span>{t('code.language')}</span>
          <select
            id={`${idPrefix}-language`}
            value={prefs.language}
            onChange={(event) => setPrefs({ ...prefs, language: event.target.value as EditorPreferences['language'] })}
          >
            {languages.map((language) => (
              <option key={language.id} value={language.id}>
                {language.name}
              </option>
            ))}
          </select>
        </label>

        <details className="code-settings">
          <summary>{t('code.settings')}</summary>
          <div className="code-settings-body">
            <label htmlFor={`${idPrefix}-mode`}>
              <span>{t('code.editorMode')}</span>
              <select
                id={`${idPrefix}-mode`}
                value={prefs.mode}
                onChange={(event) => setPrefs({ ...prefs, mode: event.target.value as EditorPreferences['mode'] })}
              >
                {question.editorModes.map((mode) => (
                  <option key={mode} value={mode}>
                    {t(`code.mode.${mode}`)}
                  </option>
                ))}
              </select>
            </label>
            <label htmlFor={`${idPrefix}-tabs`}>
              <span>{t('code.tabSpaces')}</span>
              <select
                id={`${idPrefix}-tabs`}
                value={prefs.tabSize}
                onChange={(event) => setPrefs({ ...prefs, tabSize: Number(event.target.value) as EditorPreferences['tabSize'] })}
              >
                {question.tabSizes.map((size) => (
                  <option key={size} value={size}>
                    {t('code.spaces', { n: size })}
                  </option>
                ))}
              </select>
            </label>
          </div>
        </details>

        <span className={`badge ${question.autocomplete ? 'badge-success' : 'badge-neutral'}`} data-testid="autocomplete-state">
          {question.autocomplete ? t('code.autocompleteOn') : t('code.autocompleteOff')}
        </span>
      </div>

      <div dir="ltr">
        <Suspense fallback={<Spinner label={t('code.loadingEditor')} />}>
          <CodeEditor
            value={value}
            onChange={onChange}
            language={prefs.language}
            mode={prefs.mode}
            tabSize={prefs.tabSize}
            autocomplete={question.autocomplete}
            ariaLabel={t('code.editorLabel')}
          />
        </Suspense>
      </div>
    </div>
  );
}

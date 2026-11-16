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

// What a student sees for a code question: a toolbar (language) above the editor. Only the languages the teacher
// allowed are offered, and the student's choices are kept for the session. Auto-completion is
// the teacher's decision, so it is shown as a state, not a switch.
export function CodeAnswerPanel({ examId, question, value, onChange, idPrefix }: CodeAnswerPanelProps) {
  const { t } = useI18n();
  const [prefs, setPrefs] = useState<EditorPreferences>(() => {
    const saved = readPreferences(examId, question.id);
    return {
      language: saved.language && question.languages.includes(saved.language) ? saved.language : question.defaultLanguage,
    };
  });

  useEffect(() => writePreferences(examId, question.id, prefs), [examId, question.id, prefs]);

  // Code is not carried from one language to another and is never converted: the answer is emptied together with the
  // language. The editor is keyed by language, so it starts fresh (no undo history that could bring the old code back).
  const changeLanguage = (language: EditorPreferences['language']) => {
    if (language === prefs.language) return;
    setPrefs((previous) => ({ ...previous, language }));
    onChange('');
  };

  const languages = CODE_LANGUAGES.filter((language) => question.languages.includes(language.id));

  return (
    <div className="code-panel">
      <div className="code-toolbar">
        <label className="code-toolbar-field" htmlFor={`${idPrefix}-language`}>
          <span>{t('code.language')}</span>
          <select
            id={`${idPrefix}-language`}
            dir="ltr"
            value={prefs.language}
            onChange={(event) => changeLanguage(event.target.value as EditorPreferences['language'])}
          >
            {languages.map((language) => (
              <option key={language.id} value={language.id}>
                {language.name}
              </option>
            ))}
          </select>
        </label>

        <span className={`badge ${question.autoCompletionEnabled ? 'badge-success' : 'badge-neutral'}`} data-testid="autocomplete-state">
          {question.autoCompletionEnabled ? t('code.autocompleteOn') : t('code.autocompleteOff')}
        </span>
      </div>

      <div dir="ltr">
        <Suspense fallback={<Spinner label={t('code.loadingEditor')} />}>
          <CodeEditor
            key={prefs.language}
            value={value}
            onChange={onChange}
            language={prefs.language}
            autocomplete={question.autoCompletionEnabled}
            ariaLabel={t('code.editorLabel')}
          />
        </Suspense>
      </div>
    </div>
  );
}

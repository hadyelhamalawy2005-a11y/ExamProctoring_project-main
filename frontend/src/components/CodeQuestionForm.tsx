import { useState, type FormEvent } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import {
  CODE_LANGUAGES,
  validateCodeQuestion,
  type CodeLanguageId,
  type CodeQuestion,
  type CodeQuestionProblem,
} from '../types/code';
import { hasValidDecimals, parseMarks } from '../utils/marks';
import { LIMITS } from '../utils/validation';
import { FormField } from './FormField';
import { Switch } from './Switch';

interface CodeQuestionFormProps {
  question: CodeQuestion;
  onSubmit(question: CodeQuestion): void;
  onCancel(): void;
}

const toggle = <T,>(list: readonly T[], item: T): T[] => (list.includes(item) ? list.filter((entry) => entry !== item) : [...list, item]);

// The teacher's setup for one code question. Every list needs at least one entry and the default must be one of them.
// Nothing here runs or grades code. There is no starter code field: it will be generated from the question and the
// language once the backend has an AI service, and until then the student starts with an empty editor.
export function CodeQuestionForm({ question, onSubmit, onCancel }: CodeQuestionFormProps) {
  const { t } = useI18n();
  const [draft, setDraft] = useState<CodeQuestion>(question);
  const [marksText, setMarksText] = useState(String(question.marks));
  const [problems, setProblems] = useState<CodeQuestionProblem[]>([]);
  const id = `cq-${question.id}`;

  const update = (patch: Partial<CodeQuestion>) => setDraft((previous) => ({ ...previous, ...patch }));

  // Unticking the option that was the default moves the default to the first one left.
  const setLanguages = (languages: CodeLanguageId[]) =>
    setDraft((previous) => ({
      ...previous,
      languages,
      defaultLanguage: languages.includes(previous.defaultLanguage) || languages.length === 0 ? previous.defaultLanguage : languages[0],
    }));

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    const marks = parseMarks(marksText);
    const candidate: CodeQuestion = { ...draft, text: draft.text.trim(), marks: marks ?? 0 };
    const found = validateCodeQuestion(candidate);
    if (marks !== null && (marks > LIMITS.maxMarks || !hasValidDecimals(marks)) && !found.includes('marks')) found.push('marks');
    setProblems(found);
    if (found.length === 0) onSubmit(candidate);
  };

  const error = (problem: CodeQuestionProblem) => (problems.includes(problem) ? t(`code.problem.${problem}`) : undefined);

  return (
    <form className="question-form" onSubmit={handleSubmit} noValidate aria-label={t('code.formLabel')}>
      <div className="alert alert-info">{t('code.localNotice')}</div>

      <FormField id={`${id}-marks`} label={t('qform.marks')} error={error('marks')} hint={t('qform.marksHint')}>
        <input id={`${id}-marks`} dir="ltr" inputMode="decimal" value={marksText} onChange={(event) => setMarksText(event.target.value)} />
      </FormField>

      <FormField id={`${id}-text`} label={t('qform.text')} error={error('text')}>
        <textarea id={`${id}-text`} dir="auto" rows={3} value={draft.text} onChange={(event) => update({ text: event.target.value })} />
      </FormField>

      <fieldset className="options-editor">
        <legend>{t('code.allowedLanguages')}</legend>
        <div className="check-row">
          {CODE_LANGUAGES.map((language) => (
            <label key={language.id} className="check">
              <input type="checkbox" checked={draft.languages.includes(language.id)} onChange={() => setLanguages(toggle(draft.languages, language.id))} />
              <bdi dir="ltr">{language.name}</bdi>
            </label>
          ))}
        </div>
        <label htmlFor={`${id}-deflang`}>
          <span>{t('code.defaultLanguage')}</span>
          <select id={`${id}-deflang`} dir="ltr" value={draft.defaultLanguage} onChange={(event) => update({ defaultLanguage: event.target.value as CodeLanguageId })}>
            {CODE_LANGUAGES.filter((language) => draft.languages.includes(language.id)).map((language) => (
              <option key={language.id} value={language.id}>
                {language.name}
              </option>
            ))}
          </select>
        </label>
        {error('languages') && <p className="field-error">{error('languages')}</p>}
        <p className="field-hint">{t('code.languagesNote')}</p>
      </fieldset>

      <div className="starter-placeholder" role="note">
        <strong>{t('code.starterAuto')}</strong>
        <p>{t('code.starterAutoBody')}</p>
      </div>

      <Switch
        id={`${id}-autocompletion`}
        label={t('code.autoCompletion')}
        hint={t('code.autoCompletionHint')}
        checked={draft.autoCompletionEnabled}
        onChange={(autoCompletionEnabled) => update({ autoCompletionEnabled })}
      />
      {error('defaults') && <p className="field-error">{error('defaults')}</p>}

      <div className="form-actions">
        <button type="button" className="button button-secondary" onClick={onCancel}>
          {t('common.cancel')}
        </button>
        <button type="submit" className="button">
          {t('code.save')}
        </button>
      </div>
    </form>
  );
}

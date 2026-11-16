import { useState, type FormEvent } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import {
  CODE_LANGUAGES,
  EDITOR_MODES,
  TAB_SIZES,
  validateCodeQuestion,
  type CodeLanguageId,
  type CodeQuestion,
  type CodeQuestionProblem,
  type EditorMode,
  type TabSize,
} from '../types/code';
import { hasValidDecimals, parseMarks } from '../utils/marks';
import { LIMITS } from '../utils/validation';
import { FormField } from './FormField';

interface CodeQuestionFormProps {
  question: CodeQuestion;
  onSubmit(question: CodeQuestion): void;
  onCancel(): void;
}

const toggle = <T,>(list: readonly T[], item: T): T[] => (list.includes(item) ? list.filter((entry) => entry !== item) : [...list, item]);

// The teacher's setup for one code question. Every list needs at least one entry and the default must be one of them.
// Nothing here runs code: how the answer is evaluated is only a setting until the backend supports it.
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
  const setModes = (editorModes: EditorMode[]) =>
    setDraft((previous) => ({
      ...previous,
      editorModes,
      defaultMode: editorModes.includes(previous.defaultMode) || editorModes.length === 0 ? previous.defaultMode : editorModes[0],
    }));
  const setTabSizes = (tabSizes: TabSize[]) =>
    setDraft((previous) => ({
      ...previous,
      tabSizes,
      defaultTabSize: tabSizes.includes(previous.defaultTabSize) || tabSizes.length === 0 ? previous.defaultTabSize : tabSizes[0],
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

      <div className="form-row">
        <FormField id={`${id}-marks`} label={t('qform.marks')} error={error('marks')} hint={t('qform.marksHint')}>
          <input id={`${id}-marks`} dir="ltr" inputMode="decimal" value={marksText} onChange={(event) => setMarksText(event.target.value)} />
        </FormField>
        <FormField id={`${id}-eval`} label={t('code.evaluation')}>
          <select id={`${id}-eval`} value={draft.evaluation} onChange={(event) => update({ evaluation: event.target.value as CodeQuestion['evaluation'] })}>
            <option value="manual">{t('code.eval.manual')}</option>
            <option value="ai">{t('code.eval.ai')}</option>
          </select>
        </FormField>
      </div>
      <p className="field-hint">{draft.evaluation === 'ai' ? t('code.eval.aiNote') : t('code.eval.manualNote')}</p>

      <FormField id={`${id}-text`} label={t('qform.text')} error={error('text')}>
        <textarea id={`${id}-text`} dir="auto" rows={3} value={draft.text} onChange={(event) => update({ text: event.target.value })} />
      </FormField>

      <FormField id={`${id}-starter`} label={t('code.starter')} hint={t('code.starterHint')}>
        <textarea id={`${id}-starter`} dir="ltr" rows={4} className="mono" value={draft.starterCode} onChange={(event) => update({ starterCode: event.target.value })} />
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

      <fieldset className="options-editor">
        <legend>{t('code.allowedModes')}</legend>
        <div className="check-row">
          {EDITOR_MODES.map((mode) => (
            <label key={mode} className="check">
              <input type="checkbox" checked={draft.editorModes.includes(mode)} onChange={() => setModes(toggle(draft.editorModes, mode))} />
              {t(`code.mode.${mode}`)}
            </label>
          ))}
        </div>
        <label htmlFor={`${id}-defmode`}>
          <span>{t('code.defaultMode')}</span>
          <select id={`${id}-defmode`} value={draft.defaultMode} onChange={(event) => update({ defaultMode: event.target.value as EditorMode })}>
            {draft.editorModes.map((mode) => (
              <option key={mode} value={mode}>
                {t(`code.mode.${mode}`)}
              </option>
            ))}
          </select>
        </label>
        {error('modes') && <p className="field-error">{error('modes')}</p>}
      </fieldset>

      <fieldset className="options-editor">
        <legend>{t('code.allowedTabs')}</legend>
        <div className="check-row">
          {TAB_SIZES.map((size) => (
            <label key={size} className="check">
              <input type="checkbox" checked={draft.tabSizes.includes(size)} onChange={() => setTabSizes(toggle(draft.tabSizes, size))} />
              {t('code.spaces', { n: size })}
            </label>
          ))}
        </div>
        <label htmlFor={`${id}-deftab`}>
          <span>{t('code.defaultTab')}</span>
          <select id={`${id}-deftab`} value={draft.defaultTabSize} onChange={(event) => update({ defaultTabSize: Number(event.target.value) as TabSize })}>
            {draft.tabSizes.map((size) => (
              <option key={size} value={size}>
                {t('code.spaces', { n: size })}
              </option>
            ))}
          </select>
        </label>
        {error('tabSizes') && <p className="field-error">{error('tabSizes')}</p>}
      </fieldset>

      <label className="check">
        <input type="checkbox" checked={draft.autocomplete} onChange={(event) => update({ autocomplete: event.target.checked })} />
        {t('code.autocompleteAllow')}
      </label>
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

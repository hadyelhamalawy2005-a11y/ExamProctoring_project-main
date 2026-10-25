import { useI18n } from '../i18n/LanguageContext';
import { resolveMsg } from '../i18n/serverMessages';
import { issueText, isBlocked, type QuestionDraft } from '../utils/importDraft';
import type { FieldErrors } from '../utils/validation';
import { FormField, describedBy } from './FormField';

interface ImportQuestionCardProps {
  draft: QuestionDraft;
  errors: FieldErrors; // checks of the current text (after the first import attempt) plus the backend's answer to it
  onChange(change: (draft: QuestionDraft) => QuestionDraft): void;
  onRemove(): void;
}

// One question read from the Word document, editable before it is imported: text, points, options, which option is
// correct, and the model answer of an essay. The problems the backend found are listed until the question is edited.
export function ImportQuestionCard({ draft, errors, onChange, onRemove }: ImportQuestionCardProps) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const id = `imp-${draft.key}`;
  const blocked = isBlocked(draft);
  const edit = (change: (current: QuestionDraft) => QuestionDraft) => onChange((current) => ({ ...change(current), edited: true }));

  const optionsErrorId = `${id}-options-error`;

  return (
    <li className={`import-card ${blocked ? 'import-card-problem' : ''}`} aria-labelledby={`${id}-heading`}>
      <div className="import-card-head">
        <h3 id={`${id}-heading`}>{t('import.card.heading', { n: formatNumber(draft.number) })}</h3>
        <span className="badge badge-neutral">{draft.type === 'Mcq' ? t('questions.typeMcq') : t('questions.typeEssay')}</span>
        {blocked && <span className="badge badge-cancelled">{t('import.card.attention')}</span>}
        <button type="button" className="button button-danger-outline button-small import-card-remove" onClick={onRemove}>
          {t('import.card.remove')}
        </button>
      </div>

      {draft.issues.length > 0 &&
        (draft.edited ? (
          <p className="muted">{t('import.card.edited')}</p>
        ) : (
          <ul className="import-issues">
            {draft.issues.map((issue, index) => (
              <li key={index} className={issue.severity === 'error' ? 'import-issue-error' : 'import-issue-warning'}>
                {issueText(issue, i18n)}
              </li>
            ))}
          </ul>
        ))}

      <FormField id={`${id}-text`} label={t('qform.text')} error={errors.text}>
        <textarea
          id={`${id}-text`}
          dir="auto"
          rows={3}
          value={draft.text}
          onChange={(event) => edit((current) => ({ ...current, text: event.target.value }))}
          aria-invalid={Boolean(errors.text)}
          aria-describedby={describedBy(`${id}-text`, errors.text)}
        />
      </FormField>

      <FormField
        id={`${id}-marks`}
        label={t('qform.marks')}
        error={errors.marks}
        hint={draft.marksDefaulted && !draft.edited ? t('import.card.defaultMarks', { n: formatNumber(Number(draft.marks) || 0) }) : t('qform.marksHint')}
      >
        <input
          id={`${id}-marks`}
          dir="ltr"
          inputMode="decimal"
          value={draft.marks}
          onChange={(event) => edit((current) => ({ ...current, marks: event.target.value, marksDefaulted: false }))}
          aria-invalid={Boolean(errors.marks)}
          aria-describedby={describedBy(`${id}-marks`, errors.marks, true)}
        />
      </FormField>

      {draft.type === 'Mcq' ? (
        <fieldset className="options-editor" aria-invalid={Boolean(errors.options)} aria-describedby={errors.options ? optionsErrorId : undefined}>
          <legend>{t('qform.options')}</legend>
          {draft.options.map((option, index) => {
            const error = errors[`options[${index}].text`] || errors[`options[${index}]`];
            const errorId = `${id}-option-${option.key}-error`;
            const number = option.label || formatNumber(index + 1);
            return (
              <div key={option.key} className={`option-row ${error ? 'field-invalid' : ''}`}>
                <input
                  type="radio"
                  name={`${id}-correct`}
                  checked={option.isCorrect}
                  onChange={() =>
                    edit((current) => ({ ...current, options: current.options.map((o) => ({ ...o, isCorrect: o.key === option.key })) }))
                  }
                  aria-label={t('qform.optionCorrect', { n: number })}
                />
                <input
                  className="option-text"
                  dir="auto"
                  value={option.text}
                  onChange={(event) =>
                    edit((current) => ({
                      ...current,
                      options: current.options.map((o) => (o.key === option.key ? { ...o, text: event.target.value } : o)),
                    }))
                  }
                  aria-label={t('qform.optionText', { n: number })}
                  aria-invalid={Boolean(error)}
                  aria-describedby={error ? errorId : undefined}
                />
                {error && (
                  <p className="field-error option-error" id={errorId}>
                    {resolveMsg(error, i18n)}
                  </p>
                )}
              </div>
            );
          })}
          {errors.options && (
            <p className="field-error" id={optionsErrorId}>
              {resolveMsg(errors.options, i18n)}
            </p>
          )}
        </fieldset>
      ) : (
        <FormField id={`${id}-model`} label={t('qform.modelAnswer')} error={errors.modelAnswer} hint={t('qform.modelHint')}>
          <textarea
            id={`${id}-model`}
            dir="auto"
            rows={2}
            value={draft.modelAnswer}
            onChange={(event) => edit((current) => ({ ...current, modelAnswer: event.target.value }))}
            aria-invalid={Boolean(errors.modelAnswer)}
            aria-describedby={describedBy(`${id}-model`, errors.modelAnswer, true)}
          />
        </FormField>
      )}

      {draft.type === 'Mcq' && draft.modelAnswer.length > 0 && <p className="muted">{t('questions.modelAnswer')} <span dir="auto">{draft.modelAnswer}</span></p>}
    </li>
  );
}

import { useRef, useState, type FormEvent } from 'react';
import { ApiError, describeError } from '../api/errors';
import { useI18n } from '../i18n/LanguageContext';
import { resolveMsg, serverFieldMsgs } from '../i18n/serverMessages';
import type { Question, QuestionRequest, QuestionType } from '../types/api';
import { focusFirstInvalid } from '../utils/focus';
import { LIMITS, validateQuestionDraft, type FieldErrors } from '../utils/validation';
import { Alert } from './Feedback';
import { FormField, describedBy } from './FormField';

interface OptionDraft {
  key: number;
  text: string;
  isCorrect: boolean;
}

interface QuestionFormProps {
  question?: Question; // edit mode when present
  onSubmit(request: QuestionRequest): Promise<void>;
  onCancel(): void;
}

// One form for create and replace (QuestionRequest). The whole question is sent each time, with all of its options in
// display order; the backend replaces the stored options and gives them new ids.
export function QuestionForm({ question, onSubmit, onCancel }: QuestionFormProps) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const nextKey = useRef(0);
  const newOption = (text = '', isCorrect = false): OptionDraft => ({ key: nextKey.current++, text, isCorrect });

  const [type, setType] = useState<QuestionType>(question?.type ?? 'Mcq');
  const [text, setText] = useState(question?.text ?? '');
  const [marks, setMarks] = useState(question ? question.marks.toFixed(2) : '1');
  const [modelAnswer, setModelAnswer] = useState(question?.modelAnswer ?? '');
  const [options, setOptions] = useState<OptionDraft[]>(() =>
    question && question.options.length > 0
      ? question.options.map((option) => newOption(option.text, option.isCorrect))
      : [newOption('', true), newOption()],
  );
  const [errors, setErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState<{ cause: unknown } | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const setOptionText = (key: number, value: string) =>
    setOptions((previous) => previous.map((option) => (option.key === key ? { ...option, text: value } : option)));
  const markCorrect = (key: number) =>
    setOptions((previous) => previous.map((option) => ({ ...option, isCorrect: option.key === key })));
  const removeOption = (key: number) => setOptions((previous) => previous.filter((option) => option.key !== key));

  const validate = (): FieldErrors => validateQuestionDraft({ type, text, marks, modelAnswer, options });

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    setFormError(null);
    const clientErrors = validate();
    setErrors(clientErrors);
    if (Object.keys(clientErrors).length > 0) {
      focusFirstInvalid(form);
      return;
    }

    setSubmitting(true);
    try {
      await onSubmit({
        type,
        text: text.trim(),
        marks: Number(marks.trim()),
        modelAnswer: modelAnswer.trim() ? modelAnswer.trim() : null,
        options: type === 'Mcq' ? options.map((option) => ({ text: option.text.trim(), isCorrect: option.isCorrect })) : [],
      });
    } catch (error) {
      if (error instanceof ApiError && error.status === 400) {
        // Backend names: type, text, marks, modelAnswer, options, options[i].text, options[i] (index from 0).
        setErrors(serverFieldMsgs(error.fieldErrors));
        focusFirstInvalid(form);
      }
      setFormError({ cause: error });
    } finally {
      setSubmitting(false);
    }
  };

  const idPrefix = question ? `q-${question.id}` : 'q-new';
  const optionsErrorId = `${idPrefix}-options-error`;

  return (
    <form className="question-form" onSubmit={(event) => void handleSubmit(event)} noValidate>
      {formError && <Alert tone="error">{describeError(formError.cause, i18n)}</Alert>}

      <div className="form-row">
        <FormField id={`${idPrefix}-type`} label={t('qform.type')} error={errors.type}>
          <select
            id={`${idPrefix}-type`}
            value={type}
            onChange={(event) => setType(event.target.value as QuestionType)}
            aria-invalid={Boolean(errors.type)}
            aria-describedby={describedBy(`${idPrefix}-type`, errors.type)}
          >
            <option value="Mcq">{t('qform.typeMcq')}</option>
            <option value="Essay">{t('qform.typeEssay')}</option>
          </select>
        </FormField>
        <FormField id={`${idPrefix}-marks`} label={t('qform.marks')} error={errors.marks} hint={t('qform.marksHint')}>
          <input
            id={`${idPrefix}-marks`}
            dir="ltr"
            inputMode="decimal"
            value={marks}
            onChange={(event) => setMarks(event.target.value)}
            aria-invalid={Boolean(errors.marks)}
            aria-describedby={describedBy(`${idPrefix}-marks`, errors.marks, true)}
          />
        </FormField>
      </div>

      <FormField id={`${idPrefix}-text`} label={t('qform.text')} error={errors.text}>
        <textarea
          id={`${idPrefix}-text`}
          dir="auto"
          rows={3}
          value={text}
          onChange={(event) => setText(event.target.value)}
          aria-invalid={Boolean(errors.text)}
          aria-describedby={describedBy(`${idPrefix}-text`, errors.text)}
        />
      </FormField>

      {type === 'Mcq' && (
        <fieldset
          className="options-editor"
          aria-invalid={Boolean(errors.options)}
          aria-describedby={errors.options ? optionsErrorId : undefined}
        >
          <legend>{t('qform.options')}</legend>
          {options.map((option, index) => {
            const optionError = errors[`options[${index}].text`] || errors[`options[${index}]`];
            const optionErrorId = `${idPrefix}-option-${option.key}-error`;
            const number = formatNumber(index + 1);
            return (
              <div key={option.key} className={`option-row ${optionError ? 'field-invalid' : ''}`}>
                <input
                  type="radio"
                  name={`${idPrefix}-correct`}
                  checked={option.isCorrect}
                  onChange={() => markCorrect(option.key)}
                  aria-label={t('qform.optionCorrect', { n: number })}
                />
                <input
                  className="option-text"
                  dir="auto"
                  value={option.text}
                  placeholder={t('qform.optionPlaceholder', { n: number })}
                  onChange={(event) => setOptionText(option.key, event.target.value)}
                  aria-label={t('qform.optionText', { n: number })}
                  aria-invalid={Boolean(optionError)}
                  aria-describedby={optionError ? optionErrorId : undefined}
                />
                <button
                  type="button"
                  className="button button-secondary button-small"
                  onClick={() => removeOption(option.key)}
                  disabled={options.length <= LIMITS.minMcqOptions}
                  aria-label={t('qform.removeOption', { n: number })}
                >
                  {t('qform.remove')}
                </button>
                {optionError && (
                  <p className="field-error option-error" id={optionErrorId}>
                    {resolveMsg(optionError, i18n)}
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
          <button type="button" className="button button-secondary button-small" onClick={() => setOptions((p) => [...p, newOption()])}>
            {t('qform.addOption')}
          </button>
          <p className="field-hint">{t('qform.optionsHint', { min: formatNumber(LIMITS.minMcqOptions) })}</p>
        </fieldset>
      )}

      <FormField id={`${idPrefix}-model`} label={t('qform.modelAnswer')} error={errors.modelAnswer} hint={t('qform.modelHint')}>
        <textarea
          id={`${idPrefix}-model`}
          dir="auto"
          rows={2}
          value={modelAnswer}
          onChange={(event) => setModelAnswer(event.target.value)}
          aria-invalid={Boolean(errors.modelAnswer)}
          aria-describedby={describedBy(`${idPrefix}-model`, errors.modelAnswer, true)}
        />
      </FormField>

      <div className="form-actions">
        <button type="button" className="button button-secondary" onClick={onCancel} disabled={submitting}>
          {t('common.cancel')}
        </button>
        <button type="submit" className="button" disabled={submitting}>
          {submitting ? t('common.saving') : question ? t('qform.saveQuestion') : t('qform.addQuestion')}
        </button>
      </div>
    </form>
  );
}

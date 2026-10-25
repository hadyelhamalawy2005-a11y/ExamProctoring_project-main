import { useEffect, useRef, useState, type ChangeEvent, type DragEvent } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { ApiError, describeError, isAbortError } from '../api/errors';
import { createExam, listExams } from '../api/exams';
import { importQuestions, previewQuestionImport } from '../api/questionImport';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { Alert, Spinner } from '../components/Feedback';
import { FormField, describedBy } from '../components/FormField';
import { ImportQuestionCard } from '../components/ImportQuestionCard';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import { msg, resolveMsg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import type { Exam, ImportIssue } from '../types/api';
import { describeLocalTimeZone, localInputToApi } from '../utils/dates';
import { focusFirstInvalid } from '../utils/focus';
import { groupConfirmErrors, isBlocked, issueText, toDraft, toRequest, validateDraft, type QuestionDraft } from '../utils/importDraft';
import { LIMITS, validateExamForm, type ExamFormValues, type FieldErrors } from '../utils/validation';

const MAX_FILE_BYTES = 10 * 1024 * 1024;
const DOCX_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

type Step = 'upload' | 'review' | 'done';
type Target = 'existing' | 'new';

const NEW_EXAM: ExamFormValues = { title: '', description: '', startsAtLocal: '', durationMinutes: '60' };

// The same checks the backend makes on the file (name, size), so a wrong file is refused before it is sent.
function checkFile(file: File): Msg | null {
  if (!file.name.toLowerCase().endsWith('.docx')) return msg('val.fileExtension');
  if (file.size === 0) return msg('val.fileEmpty');
  if (file.size > MAX_FILE_BYTES) return msg('val.fileTooLarge');
  return null;
}

// Import questions from a Word (.docx) file in two steps: the file is read and shown for review (nothing is saved), then the
// reviewed questions are saved into an existing exam or a new one, all or none. Format: docs/Word_Import_Format.md.
export function ImportQuestionsPage() {
  const i18n = useI18n();
  const { t, formatNumber, formatDateTime } = i18n;
  const [params] = useSearchParams();

  const [step, setStep] = useState<Step>('upload');

  // ---- Step 1: the file ----
  const [file, setFile] = useState<File | null>(null);
  const [fileProblem, setFileProblem] = useState<Msg | null>(null);
  const [dragging, setDragging] = useState(false);
  const [reading, setReading] = useState(false);
  const [readError, setReadError] = useState<unknown>(null);
  const readController = useRef<AbortController | null>(null);

  // ---- Step 2: the review ----
  const [fileName, setFileName] = useState('');
  const [documentTitle, setDocumentTitle] = useState<string | null>(null);
  const [documentIssues, setDocumentIssues] = useState<ImportIssue[]>([]);
  const [drafts, setDrafts] = useState<QuestionDraft[]>([]);
  const [target, setTarget] = useState<Target>('existing');
  const [examId, setExamId] = useState(params.get('examId') ?? '');
  const [newExam, setNewExam] = useState<ExamFormValues>(NEW_EXAM);
  const [createdExam, setCreatedExam] = useState<{ id: string; title: string } | null>(null);
  const [showValidation, setShowValidation] = useState(false);
  const [serverErrors, setServerErrors] = useState<Record<string, FieldErrors>>({});
  const [examErrors, setExamErrors] = useState<FieldErrors>({});
  const [submitError, setSubmitError] = useState<unknown>(null);
  const [submitting, setSubmitting] = useState(false);
  const submittingRef = useRef(false); // set synchronously, so a double click cannot start a second import
  const [discardOpen, setDiscardOpen] = useState(false);
  const formRef = useRef<HTMLDivElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);

  // ---- Step 3 ----
  const [done, setDone] = useState<{ count: number; examId: string; title: string } | null>(null);

  const exams = useLoader((signal) => listExams({ page: 1, pageSize: 100 }, signal), []);
  // Only a Draft or Published exam that has not started accepts questions (the backend decides again on import).
  const choices: Exam[] = (exams.data?.items ?? []).filter((exam) => exam.status !== 'Cancelled' && exam.phase === 'Upcoming');

  useEffect(() => () => readController.current?.abort(), []);

  useEffect(() => {
    if (step === 'review') headingRef.current?.focus();
  }, [step]);

  // ---- File selection ----

  const selectFile = (selected: File | null) => {
    setReadError(null);
    setFile(selected);
    setFileProblem(selected ? checkFile(selected) : null);
  };

  const onPick = (event: ChangeEvent<HTMLInputElement>) => {
    selectFile(event.target.files?.[0] ?? null);
    event.target.value = ''; // the same file can be chosen again
  };

  const onDrop = (event: DragEvent) => {
    event.preventDefault();
    setDragging(false);
    selectFile(event.dataTransfer.files?.[0] ?? null);
  };

  const formatSize = (bytes: number) =>
    bytes >= 1024 * 1024
      ? t('import.sizeMb', { n: formatNumber(bytes / (1024 * 1024), { maximumFractionDigits: 1 }) })
      : t('import.sizeKb', { n: formatNumber(Math.max(1, Math.round(bytes / 1024))) });

  const read = async () => {
    if (!file || fileProblem || reading) return;
    setReading(true);
    setReadError(null);
    const controller = new AbortController();
    readController.current = controller;
    try {
      const preview = await previewQuestionImport(file, controller.signal);
      setFileName(file.name);
      setDocumentTitle(preview.examTitle);
      setDocumentIssues(preview.issues);
      setDrafts(preview.questions.map(toDraft));
      setNewExam({ ...NEW_EXAM, title: preview.examTitle ?? '' });
      setShowValidation(false);
      setServerErrors({});
      setExamErrors({});
      setSubmitError(null);
      setCreatedExam(null);
      setStep('review');
    } catch (error) {
      if (!isAbortError(error)) setReadError(error);
    } finally {
      setReading(false);
    }
  };

  const reset = () => {
    setStep('upload');
    setFile(null);
    setFileProblem(null);
    setReadError(null);
    setDrafts([]);
    setDone(null);
    setDiscardOpen(false);
  };

  // ---- Review ----

  const changeDraft = (key: string, change: (draft: QuestionDraft) => QuestionDraft) => {
    setDrafts((previous) => previous.map((draft) => (draft.key === key ? change(draft) : draft)));
    setServerErrors((previous) => {
      if (!(key in previous)) return previous;
      const rest = { ...previous };
      delete rest[key];
      return rest;
    });
  };

  const errorsOf = (draft: QuestionDraft): FieldErrors => ({
    ...(showValidation ? validateDraft(draft) : {}),
    ...(serverErrors[draft.key] ?? {}),
  });

  const problemCount = drafts.filter((draft) => isBlocked(draft)).length;
  const blocked = problemCount > 0;

  const examChecks = (): FieldErrors => {
    if (target === 'existing') return examId ? {} : { examId: msg('val.examRequired') };
    if (createdExam) return {};
    return validateExamForm(newExam, { startTimeChanged: true });
  };

  const submit = async () => {
    if (submittingRef.current || drafts.length === 0 || blocked) return;
    setShowValidation(true);
    const targetErrors = examChecks();
    setExamErrors(targetErrors);
    if (Object.keys(targetErrors).length > 0 || drafts.some((draft) => Object.keys(validateDraft(draft)).length > 0)) {
      focusFirstInvalid(formRef.current);
      return;
    }

    submittingRef.current = true;
    setSubmitting(true);
    setSubmitError(null);
    setServerErrors({});
    let phase: 'exam' | 'import' = 'exam';
    try {
      let targetId = examId;
      let targetTitle = choices.find((exam) => exam.id === examId)?.title ?? '';
      if (target === 'new') {
        if (createdExam) {
          targetId = createdExam.id;
          targetTitle = createdExam.title;
        } else {
          const created = await createExam({
            title: newExam.title.trim(),
            description: newExam.description.trim() ? newExam.description.trim() : null,
            startsAt: localInputToApi(newExam.startsAtLocal)!,
            durationMinutes: Number(newExam.durationMinutes),
          });
          setCreatedExam({ id: created.id, title: created.title });
          targetId = created.id;
          targetTitle = created.title;
        }
      }

      phase = 'import';
      const saved = await importQuestions(targetId, drafts.map(toRequest));
      setDone({ count: saved.items.length, examId: targetId, title: targetTitle });
      setStep('done');
    } catch (error) {
      setSubmitError(error);
      if (error instanceof ApiError && error.status === 400) {
        if (phase === 'exam') {
          setExamErrors(serverFieldMsgs(error.fieldErrors));
        } else {
          const grouped = groupConfirmErrors(error.fieldErrors);
          const next: Record<string, FieldErrors> = {};
          grouped.forEach((fields, index) => {
            const draft = drafts[index];
            if (draft) next[draft.key] = serverFieldMsgs(fields, { all: true });
          });
          setServerErrors(next);
        }
        focusFirstInvalid(formRef.current);
      }
    } finally {
      submittingRef.current = false;
      setSubmitting(false);
    }
  };

  const zone = describeLocalTimeZone();
  const readFileError =
    readError instanceof ApiError && readError.status === 400 && readError.fieldErrors.file
      ? resolveMsg({ server: readError.fieldErrors.file }, i18n)
      : readError != null
        ? describeError(readError, i18n)
        : null;

  // ---- Render ----

  if (step === 'done' && done) {
    return (
      <div className="page page-narrow">
        <section className="card success-panel" aria-labelledby="import-done">
          <h1 id="import-done">{t('import.doneTitle')}</h1>
          <Alert tone="success">
            {t('import.doneBody', { count: done.count === 1 ? t('questions.countOne', { n: 1 }) : t('questions.countMany', { n: formatNumber(done.count) }), exam: done.title })}
          </Alert>
          <div className="button-row">
            <Link className="button" to={`/exams/${done.examId}`}>
              {t('import.openExam')}
            </Link>
            <button type="button" className="button button-secondary" onClick={reset}>
              {t('import.another')}
            </button>
          </div>
        </section>
      </div>
    );
  }

  if (step === 'review') {
    return (
      <div className="page" ref={formRef}>
        <div>
          <h1 ref={headingRef} tabIndex={-1}>
            {t('import.reviewTitle')}
          </h1>
          <p className="muted">
            {t('import.fromFile', { file: fileName })}
            {documentTitle ? ` · ${t('import.docTitle', { title: documentTitle })}` : ''}
          </p>
        </div>

        {drafts.length > 0 && (
          <Alert tone={blocked ? 'warning' : 'success'}>
            {t('import.summary', {
              count: drafts.length === 1 ? t('questions.countOne', { n: 1 }) : t('questions.countMany', { n: formatNumber(drafts.length) }),
              problems: formatNumber(problemCount),
            })}
            {' · '}
            {blocked ? t('import.fixFirst') : t('import.allGood')}
          </Alert>
        )}
        {drafts.length === 0 && <Alert tone="warning">{t('import.noneLeft')}</Alert>}

        {documentIssues.length > 0 && (
          <section className="card" aria-labelledby="import-notes">
            <h2 id="import-notes">{t('import.notesTitle')}</h2>
            <ul className="import-issues">
              {documentIssues.map((issue, index) => (
                <li key={index} className={issue.severity === 'error' ? 'import-issue-error' : 'import-issue-warning'}>
                  {issueText(issue, i18n)}
                </li>
              ))}
            </ul>
          </section>
        )}

        <fieldset className="card import-target">
          <legend>{t('import.target.title')}</legend>
          <div className="import-target-options" role="radiogroup" aria-label={t('import.target.title')}>
            <label>
              <input type="radio" name="import-target" checked={target === 'existing'} disabled={submitting} onChange={() => setTarget('existing')} />{' '}
              {t('import.target.existing')}
            </label>
            <label>
              <input type="radio" name="import-target" checked={target === 'new'} disabled={submitting} onChange={() => setTarget('new')} />{' '}
              {t('import.target.new')}
            </label>
          </div>

          {target === 'existing' ? (
            <div className="form">
              <p className="muted">{t('import.target.help')}</p>
              {exams.loading && !exams.data && <Spinner label={t('import.target.loading')} />}
              {exams.error != null && (
                <Alert tone="error">
                  {describeError(exams.error, i18n)}{' '}
                  <button type="button" className="link-button" onClick={exams.reload}>
                    {t('common.tryAgain')}
                  </button>
                </Alert>
              )}
              {exams.data && choices.length === 0 && <Alert tone="info">{t('import.target.none')}</Alert>}
              {choices.length > 0 && (
                <FormField id="import-exam" label={t('import.target.exam')} error={examErrors.examId}>
                  <select
                    id="import-exam"
                    value={examId}
                    disabled={submitting}
                    onChange={(event) => {
                      setExamId(event.target.value);
                      setExamErrors({});
                    }}
                    aria-invalid={Boolean(examErrors.examId)}
                    aria-describedby={describedBy('import-exam', examErrors.examId)}
                  >
                    <option value="">{t('import.target.choose')}</option>
                    {choices.map((exam) => (
                      <option key={exam.id} value={exam.id}>
                        {exam.title} — {formatDateTime(exam.startsAt)}
                      </option>
                    ))}
                  </select>
                </FormField>
              )}
            </div>
          ) : (
            <div className="form">
              <p className="muted">{t('import.target.newHelp')}</p>
              {createdExam && <Alert tone="info">{t('import.target.created', { title: createdExam.title })}</Alert>}
              <FormField id="import-new-title" label={t('examForm.title')} error={examErrors.title}>
                <input
                  id="import-new-title"
                  dir="auto"
                  value={newExam.title}
                  disabled={submitting || createdExam !== null}
                  onChange={(event) => setNewExam((previous) => ({ ...previous, title: event.target.value }))}
                  aria-invalid={Boolean(examErrors.title)}
                  aria-describedby={describedBy('import-new-title', examErrors.title)}
                />
              </FormField>
              <FormField id="import-new-description" label={t('examForm.description')} error={examErrors.description}>
                <textarea
                  id="import-new-description"
                  dir="auto"
                  rows={2}
                  value={newExam.description}
                  disabled={submitting || createdExam !== null}
                  onChange={(event) => setNewExam((previous) => ({ ...previous, description: event.target.value }))}
                  aria-invalid={Boolean(examErrors.description)}
                  aria-describedby={describedBy('import-new-description', examErrors.description)}
                />
              </FormField>
              <div className="form-row">
                <FormField
                  id="import-new-start"
                  label={t('examForm.start')}
                  error={examErrors.startsAt}
                  hint={t('examForm.tzHint', { zone: `⁦${zone}⁩` })}
                >
                  <input
                    id="import-new-start"
                    type="datetime-local"
                    value={newExam.startsAtLocal}
                    disabled={submitting || createdExam !== null}
                    onChange={(event) => setNewExam((previous) => ({ ...previous, startsAtLocal: event.target.value }))}
                    aria-invalid={Boolean(examErrors.startsAt)}
                    aria-describedby={describedBy('import-new-start', examErrors.startsAt, true)}
                  />
                </FormField>
                <FormField
                  id="import-new-duration"
                  label={t('examForm.duration')}
                  error={examErrors.durationMinutes}
                  hint={t('examForm.durationHint', { min: formatNumber(LIMITS.durationMin), max: formatNumber(LIMITS.durationMax) })}
                >
                  <input
                    id="import-new-duration"
                    type="number"
                    inputMode="numeric"
                    min={LIMITS.durationMin}
                    max={LIMITS.durationMax}
                    step={1}
                    value={newExam.durationMinutes}
                    disabled={submitting || createdExam !== null}
                    onChange={(event) => setNewExam((previous) => ({ ...previous, durationMinutes: event.target.value }))}
                    aria-invalid={Boolean(examErrors.durationMinutes)}
                    aria-describedby={describedBy('import-new-duration', examErrors.durationMinutes, true)}
                  />
                </FormField>
              </div>
            </div>
          )}
        </fieldset>

        <ol className="import-list">
          {drafts.map((draft) => (
            <ImportQuestionCard
              key={draft.key}
              draft={draft}
              errors={errorsOf(draft)}
              onChange={(change) => changeDraft(draft.key, change)}
              onRemove={() => setDrafts((previous) => previous.filter((item) => item.key !== draft.key))}
            />
          ))}
        </ol>

        {submitError != null && <Alert tone="error">{describeError(submitError, i18n)}</Alert>}

        <div className="form-actions">
          <button type="button" className="button button-secondary" onClick={() => setDiscardOpen(true)} disabled={submitting}>
            {t('import.action.cancel')}
          </button>
          <button
            type="button"
            className="button"
            onClick={() => void submit()}
            disabled={submitting || drafts.length === 0 || blocked}
            aria-busy={submitting}
          >
            {submitting
              ? t('import.action.importing')
              : t('import.action.import', {
                  count: drafts.length === 1 ? t('questions.countOne', { n: 1 }) : t('questions.countMany', { n: formatNumber(drafts.length) }),
                })}
          </button>
        </div>

        <ConfirmDialog
          open={discardOpen}
          title={t('import.discardTitle')}
          confirmLabel={t('import.discard')}
          tone="danger"
          onConfirm={reset}
          onCancel={() => setDiscardOpen(false)}
        >
          <p>{t('import.discardBody')}</p>
        </ConfirmDialog>
      </div>
    );
  }

  return (
    <div className="page page-narrow">
      <div>
        <h1>{t('import.title')}</h1>
        <p className="muted">{t('import.intro')}</p>
      </div>

      <section className="card form" aria-label={t('import.title')}>
        <div
          className={`dropzone ${dragging ? 'dropzone-active' : ''}`}
          onDragOver={(event) => {
            event.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={onDrop}
        >
          <label className="button button-secondary dropzone-button">
            {t('import.chooseFile')}
            <input
              type="file"
              className="sr-only"
              accept={`.docx,${DOCX_TYPE}`}
              onChange={onPick}
              disabled={reading}
              aria-invalid={fileProblem !== null}
              aria-describedby={fileProblem ? 'import-file-error' : undefined}
            />
          </label>
          <span className="muted">{dragging ? t('import.dropActive') : t('import.drop')}</span>
        </div>

        {file && (
          <p className="import-file">
            <strong>{t('import.selectedFile')}:</strong> <span dir="auto">{file.name}</span> ({formatSize(file.size)}){' '}
            <button type="button" className="link-button" onClick={() => selectFile(null)} disabled={reading}>
              {t('import.removeFile')}
            </button>
          </p>
        )}
        {fileProblem && (
          <p className="field-error" id="import-file-error">
            {resolveMsg(fileProblem, i18n)}
          </p>
        )}
        {readFileError && <Alert tone="error">{readFileError}</Alert>}

        <div className="form-actions">
          <a className="link-button" href="/question-import-template.docx" download>
            {t('import.template')}
          </a>
          <button type="button" className="button" onClick={() => void read()} disabled={!file || fileProblem !== null || reading} aria-busy={reading}>
            {reading ? t('import.reading') : t('import.read')}
          </button>
        </div>
        {reading && <Spinner label={t('import.reading')} />}
      </section>

      <details className="card import-guide">
        <summary>{t('import.guideTitle')}</summary>
        <p>{t('import.guideIntro')}</p>
        <pre dir="ltr">{GUIDE_EXAMPLE}</pre>
        <ul>
          <li>{t('import.guideRule1')}</li>
          <li>{t('import.guideRule2')}</li>
          <li>{t('import.guideRule3')}</li>
          <li>{t('import.guideRule4')}</li>
          <li>{t('import.guideRule5')}</li>
        </ul>
      </details>
    </div>
  );
}

const GUIDE_EXAMPLE = `Exam Title: Introduction to Computer Science

Section 1: Multiple Choice Questions
Q1: What does CPU stand for?
A) Central Processing Unit
B) Computer Personal Unit
C) Central Program Utility
D) Control Processing User
Correct Answer: A
Points: 2

س2: ما هي عاصمة فرنسا؟
أ) لندن
ب) باريس
الإجابة الصحيحة: ب

Section 2: Essay Questions
Q3: Explain the difference between RAM and storage.
Model Answer: RAM is fast temporary memory.`;

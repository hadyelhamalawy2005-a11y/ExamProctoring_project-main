import { useState } from 'react';
import { Link } from 'react-router-dom';
import { deleteExam, runLifecycleAction, type LifecycleAction } from '../api/exams';
import { ApiError, describeError } from '../api/errors';
import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import type { Exam } from '../types/api';
import { ConfirmDialog } from './ConfirmDialog';
import { Alert } from './Feedback';

type PendingAction = LifecycleAction | 'delete';

const CONFIRMATIONS: Record<PendingAction, { title: TranslationKey; body: TranslationKey; label: TranslationKey; tone: 'danger' | 'primary' }> = {
  publish: { title: 'actions.publishTitle', body: 'actions.publishBody', label: 'actions.publish', tone: 'primary' },
  unpublish: { title: 'actions.unpublishTitle', body: 'actions.unpublishBody', label: 'actions.unpublish', tone: 'primary' },
  cancel: { title: 'actions.cancelTitle', body: 'actions.cancelBody', label: 'actions.cancelExam', tone: 'danger' },
  delete: { title: 'actions.deleteTitle', body: 'actions.deleteBody', label: 'actions.delete', tone: 'danger' },
};

const SUCCESS: Record<LifecycleAction, TranslationKey> = {
  publish: 'actions.published',
  unpublish: 'actions.unpublished',
  cancel: 'actions.cancelled',
};

interface ExamActionsProps {
  exam: Exam;
  onChanged(exam: Exam): void;
  onDeleted(): void;
  // A refusal can mean the exam changed on the server (for example it started): reload it.
  onStale(): void;
}

// What the last action produced. Errors are kept as errors (not text) so they follow the active language.
type Outcome = { tone: 'success'; action: LifecycleAction } | { tone: 'error'; error: unknown };

// Buttons follow the exam's status and phase as last loaded, but the backend decides: a refused action shows the
// server's own explanation (the ProblemDetails detail), and the page reloads the exam afterwards.
export function ExamActions({ exam, onChanged, onDeleted, onStale }: ExamActionsProps) {
  const i18n = useI18n();
  const { t } = i18n;
  const [pending, setPending] = useState<PendingAction | null>(null);
  const [busy, setBusy] = useState(false);
  const [outcome, setOutcome] = useState<Outcome | null>(null);

  const beforeStart = exam.phase === 'Upcoming';
  const canEdit = beforeStart && exam.status !== 'Cancelled';

  const run = async () => {
    if (!pending) return;
    setBusy(true);
    setOutcome(null);
    try {
      if (pending === 'delete') {
        await deleteExam(exam.id);
        setPending(null);
        onDeleted();
        return;
      }
      const updated = await runLifecycleAction(exam.id, pending);
      onChanged(updated);
      setOutcome({ tone: 'success', action: pending });
    } catch (error) {
      setOutcome({ tone: 'error', error });
      if (error instanceof ApiError && (error.status === 409 || error.status === 404)) onStale();
    } finally {
      setBusy(false);
      setPending(null);
    }
  };

  return (
    <div className="exam-actions">
      {outcome && (
        <Alert tone={outcome.tone} onDismiss={() => setOutcome(null)}>
          {outcome.tone === 'success' ? t(SUCCESS[outcome.action]) : describeError(outcome.error, i18n)}
        </Alert>
      )}

      <div className="button-row">
        {canEdit && (
          <Link className="button button-secondary" to={`/exams/${exam.id}/edit`}>
            {t('actions.edit')}
          </Link>
        )}
        {exam.status === 'Draft' && (
          <button type="button" className="button" disabled={!beforeStart} onClick={() => setPending('publish')}>
            {t('actions.publish')}
          </button>
        )}
        {exam.status === 'Published' && (
          <>
            <button
              type="button"
              className="button button-secondary"
              disabled={!beforeStart}
              onClick={() => setPending('unpublish')}
            >
              {t('actions.unpublish')}
            </button>
            <button type="button" className="button button-danger" disabled={!beforeStart} onClick={() => setPending('cancel')}>
              {t('actions.cancelExam')}
            </button>
          </>
        )}
        {exam.status === 'Draft' && (
          <button type="button" className="button button-danger-outline" onClick={() => setPending('delete')}>
            {t('actions.delete')}
          </button>
        )}
      </div>

      {exam.status === 'Cancelled' && <p className="muted">{t('actions.cancelledNote')}</p>}
      {exam.status !== 'Cancelled' && !beforeStart && (
        <p className="muted">
          {t('actions.startedNote')}
          {exam.status === 'Draft' ? ` ${t('actions.startedDraftNote')}` : ''}
        </p>
      )}

      {pending && (
        <ConfirmDialog
          open
          title={t(CONFIRMATIONS[pending].title)}
          confirmLabel={t(CONFIRMATIONS[pending].label)}
          tone={CONFIRMATIONS[pending].tone}
          busy={busy}
          onConfirm={() => void run()}
          onCancel={() => setPending(null)}
        >
          <p>{t(CONFIRMATIONS[pending].body)}</p>
        </ConfirmDialog>
      )}
    </div>
  );
}

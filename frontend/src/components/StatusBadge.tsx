import { useI18n } from '../i18n/LanguageContext';
import type { ExamPhase, ExamStatus } from '../types/api';

export function StatusBadge({ status }: { status: ExamStatus }) {
  const { t } = useI18n();
  return <span className={`badge badge-${status.toLowerCase()}`}>{t(`status.${status}`)}</span>;
}

// The phase is calculated by the backend from the start and end times when the exam was loaded.
export function PhaseBadge({ phase }: { phase: ExamPhase }) {
  const { t } = useI18n();
  return <span className={`badge badge-phase-${phase.toLowerCase()}`}>{t(`phase.${phase}`)}</span>;
}

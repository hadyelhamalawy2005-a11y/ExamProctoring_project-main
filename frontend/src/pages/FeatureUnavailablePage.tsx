import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import { EmptyState } from '../components/Feedback';
import type { IconName } from '../components/Icon';

export type Unavailable = 'incidents' | 'attempts' | 'studentExams' | 'studentResults' | 'studentExam' | 'attempt';

// What each screen would need from the server. These are plain descriptions of missing backend capabilities, not
// endpoints: none of them exists, so nothing here is called and no data is shown.
const NEEDS: Record<Unavailable, { icon: IconName; body: TranslationKey; needs: TranslationKey[] }> = {
  incidents: {
    icon: 'error',
    body: 'unavailable.incidents',
    needs: ['needs.recordIncidents', 'needs.reviewIncidents'],
  },
  attempts: {
    icon: 'assignment',
    body: 'unavailable.attempts',
    needs: ['needs.attempts', 'needs.marking'],
  },
  studentExams: {
    icon: 'assignmentOutline',
    body: 'unavailable.studentExams',
    needs: ['needs.eligibility', 'needs.studentExamList'],
  },
  studentResults: {
    icon: 'assignment',
    body: 'unavailable.studentResults',
    needs: ['needs.results'],
  },
  studentExam: {
    icon: 'assignmentOutline',
    body: 'unavailable.studentExam',
    needs: ['needs.eligibility', 'needs.studentExamList', 'needs.attempts'],
  },
  attempt: {
    icon: 'assignment',
    body: 'unavailable.attempt',
    needs: ['needs.attempts', 'needs.results'],
  },
};

// A destination of the mobile app whose data does not exist on the server yet. The screen is here so the navigation is
// complete, and it says plainly what is missing. It shows no sample data and offers no action that would pretend to work.
export function FeatureUnavailablePage({ feature }: { feature: Unavailable }) {
  const { t } = useI18n();
  const info = NEEDS[feature];
  return (
    <div className="page">
      <EmptyState icon={info.icon} title={t('unavailable.title')}>
        <p>{t(info.body)}</p>
        <p className="muted">{t('unavailable.needs')}</p>
        <ul className="needs-list">
          {info.needs.map((key) => (
            <li key={key}>{t(key)}</li>
          ))}
        </ul>
      </EmptyState>
    </div>
  );
}

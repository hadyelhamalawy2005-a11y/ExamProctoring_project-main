import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/LanguageContext';

// Step zero of creating an exam, as in the mobile app: choose ONCE how the questions will be added. Both ways create the
// same draft exam through POST /api/exams; "Word" then continues to the import screen for that exam.
export function ExamMethodPage() {
  const { t } = useI18n();
  return (
    <div className="page">
      <p className="muted">{t('methodScreen.intro')}</p>
      <Link to="/exams/new?method=manual" className="card item-card method-card">
        <h2>{t('method.manual')}</h2>
        <p>{t('methodScreen.manualBody')}</p>
      </Link>
      <Link to="/exams/new?method=word" className="card item-card method-card">
        <h2>{t('method.word')}</h2>
        <p>{t('methodScreen.wordBody')}</p>
      </Link>
    </div>
  );
}

import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/LanguageContext';
import { Icon } from '../components/Icon';

// Step zero of creating an exam, as in the mobile app: choose ONCE how the questions will be added. Both ways create the
// same draft exam through POST /api/exams; "Word" then continues to the import screen for that exam.
export function ExamMethodPage() {
  const { t } = useI18n();
  return (
    <div className="page">
      <p className="muted">{t('methodScreen.intro')}</p>
      <div className="method-grid">
        <Link to="/exams/new?method=manual" className="card item-card method-card">
          <span className="feature-tile" aria-hidden="true">
            <Icon name="edit" size={22} />
          </span>
          <h2>{t('method.manual')}</h2>
          <p>{t('methodScreen.manualBody')}</p>
        </Link>
        <Link to="/exams/new?method=word" className="card item-card method-card">
          <span className="feature-tile feature-tile-gold" aria-hidden="true">
            <Icon name="upload" size={22} />
          </span>
          <h2>{t('method.word')}</h2>
          <p>{t('methodScreen.wordBody')}</p>
        </Link>
      </div>
    </div>
  );
}

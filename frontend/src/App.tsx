import { BrowserRouter, Link, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import { RequireInstructor, RequireSession } from './auth/ProtectedRoute';
import { Layout } from './components/Layout';
import { LanguageProvider, useI18n } from './i18n/LanguageContext';
import { LanguageToggle } from './i18n/LanguageToggle';
import { ChangePasswordPage } from './pages/ChangePasswordPage';
import { CreateExamPage, EditExamPage } from './pages/ExamEditorPages';
import { ExamDetailsPage } from './pages/ExamDetailsPage';
import { ExamListPage } from './pages/ExamListPage';
import { ImportQuestionsPage } from './pages/ImportQuestionsPage';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';

function NotFoundPage() {
  const { t } = useI18n();
  return (
    <main className="auth-page">
      <div className="card auth-card">
        <div className="auth-toolbar">
          <LanguageToggle />
        </div>
        <h1>{t('notFound.title')}</h1>
        <Link to="/exams">{t('notFound.link')}</Link>
      </div>
    </main>
  );
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />
      <Route
        path="/change-password"
        element={
          <RequireSession>
            <ChangePasswordPage />
          </RequireSession>
        }
      />
      <Route
        element={
          <RequireInstructor>
            <Layout />
          </RequireInstructor>
        }
      >
        <Route path="/exams" element={<ExamListPage />} />
        <Route path="/exams/new" element={<CreateExamPage />} />
        <Route path="/import" element={<ImportQuestionsPage />} />
        <Route path="/exams/:examId" element={<ExamDetailsPage />} />
        <Route path="/exams/:examId/edit" element={<EditExamPage />} />
      </Route>
      <Route path="/" element={<Navigate to="/exams" replace />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}

export function App() {
  return (
    <LanguageProvider>
      <AuthProvider>
        <BrowserRouter>
          <AppRoutes />
        </BrowserRouter>
      </AuthProvider>
    </LanguageProvider>
  );
}

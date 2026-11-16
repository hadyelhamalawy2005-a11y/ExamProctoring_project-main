import { BrowserRouter, Link, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { RequireRole, RequireSession } from './auth/ProtectedRoute';
import { homeFor } from './auth/roles';
import { Layout } from './components/Layout';
import { PageLoader } from './components/Feedback';
import { AdminLayout, ProfileLayout, StudentLayout } from './components/RoleLayout';
import { LanguageProvider, useI18n } from './i18n/LanguageContext';
import { AdminAccountDetailPage } from './pages/AdminAccountDetailPage';
import { AdminAccountsPage } from './pages/AdminAccountsPage';
import { AdminCreateInstructorPage } from './pages/AdminCreateInstructorPage';
import { ChangePasswordPage } from './pages/ChangePasswordPage';
import { CreateExamPage, EditExamPage } from './pages/ExamEditorPages';
import { ExamDetailsPage } from './pages/ExamDetailsPage';
import { ExamListPage } from './pages/ExamListPage';
import { ExamMethodPage } from './pages/ExamMethodPage';
import { FeatureUnavailablePage } from './pages/FeatureUnavailablePage';
import { ForgotPasswordPage } from './pages/ForgotPasswordPage';
import { InstructorHomePage } from './pages/InstructorHomePage';
import { ExamPreviewPage } from './pages/ExamPreviewPage';
import { ImportQuestionsPage } from './pages/ImportQuestionsPage';
import { LoginPage } from './pages/LoginPage';
import { ProfilePage } from './pages/ProfilePage';
import { RegisterPage } from './pages/RegisterPage';
import { StudentHomePage } from './pages/StudentHomePage';
import { AuthShell } from './components/AuthShell';

function NotFoundPage() {
  const { t } = useI18n();
  return (
    <AuthShell>
      <div className="auth-card">
        <h1>{t('notFound.title')}</h1>
        <Link to="/">{t('notFound.link')}</Link>
      </div>
    </AuthShell>
  );
}

// "/" and "/instructor": send the signed-in user to their own dashboard, a visitor to sign in.
function RoleHome() {
  const { status, session } = useAuth();
  const { t } = useI18n();
  if (status === 'loading') return <PageLoader label={t('session.restoring')} />;
  if (!session) return <Navigate to="/login" replace />;
  if (session.mustChangePassword) return <Navigate to="/change-password" replace />;
  return <Navigate to={homeFor(session.user.role)} replace />;
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />
      <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      <Route
        path="/change-password"
        element={
          <RequireSession>
            <ChangePasswordPage />
          </RequireSession>
        }
      />

      {/* Instructor. The original URLs are kept (/exams, /import); /instructor is an entry point to them. */}
      <Route
        element={
          <RequireRole roles={['Instructor']}>
            <Layout />
          </RequireRole>
        }
      >
        <Route path="/instructor" element={<InstructorHomePage />} />
        <Route path="/exams" element={<ExamListPage />} />
        <Route path="/exams/new/method" element={<ExamMethodPage />} />
        <Route path="/exams/new" element={<CreateExamPage />} />
        <Route path="/incidents" element={<FeatureUnavailablePage feature="incidents" />} />
        <Route path="/incidents/:incidentId" element={<FeatureUnavailablePage feature="incidents" />} />
        <Route path="/exams/:examId/attempts" element={<FeatureUnavailablePage feature="attempts" />} />
        <Route path="/import" element={<ImportQuestionsPage />} />
        <Route path="/exams/:examId" element={<ExamDetailsPage />} />
        <Route path="/exams/:examId/edit" element={<EditExamPage />} />
        <Route path="/exams/:examId/preview" element={<ExamPreviewPage />} />
      </Route>

      {/* Administrator */}
      <Route
        path="/admin"
        element={
          <RequireRole roles={['Admin']}>
            <AdminLayout />
          </RequireRole>
        }
      >
        <Route index element={<Navigate to="accounts" replace />} />
        <Route path="accounts" element={<AdminAccountsPage />} />
        <Route path="accounts/:accountId" element={<AdminAccountDetailPage />} />
        <Route path="instructors/new" element={<AdminCreateInstructorPage />} />
      </Route>

      {/* Student: layout and placeholder only; the backend has no student exam endpoints yet. */}
      <Route
        path="/student"
        element={
          <RequireRole roles={['Student']}>
            <StudentLayout />
          </RequireRole>
        }
      >
        <Route index element={<StudentHomePage />} />
        <Route path="exams" element={<FeatureUnavailablePage feature="studentExams" />} />
        <Route path="results" element={<FeatureUnavailablePage feature="studentResults" />} />
        <Route path="exams/:examId" element={<FeatureUnavailablePage feature="studentExam" />} />
        <Route path="exams/:examId/consent" element={<FeatureUnavailablePage feature="studentExam" />} />
        <Route path="exams/:examId/system-check" element={<FeatureUnavailablePage feature="studentExam" />} />
        <Route path="attempts/:attemptId" element={<FeatureUnavailablePage feature="attempt" />} />
        <Route path="attempts/:attemptId/result" element={<FeatureUnavailablePage feature="attempt" />} />
      </Route>

      {/* Profile: the same screen for every role, inside that role's own shell. */}
      <Route
        path="/profile"
        element={
          <RequireRole roles={['Admin', 'Instructor', 'Student']}>
            <ProfileLayout />
          </RequireRole>
        }
      >
        <Route index element={<ProfilePage />} />
      </Route>

      <Route path="/" element={<RoleHome />} />
      <Route path="/instructor/*" element={<RoleHome />} />
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

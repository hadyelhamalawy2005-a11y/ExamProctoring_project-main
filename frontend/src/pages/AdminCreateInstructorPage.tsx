import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { createInstructor } from '../api/admin';
import { ApiError, describeError } from '../api/errors';
import { Alert } from '../components/Feedback';
import { FormField, describedBy } from '../components/FormField';
import { TemporaryPasswordPanel } from '../components/TemporaryPasswordPanel';
import { useI18n } from '../i18n/LanguageContext';
import { msg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import type { CreateInstructorResponse } from '../types/api';
import { focusFirstInvalid } from '../utils/focus';
import { LIMITS, validateInstructorForm } from '../utils/validation';

// POST /api/admin/instructors with exactly { fullName, email }. The 201 response carries the temporary password, which
// is shown once (kept in this component's state only) and then dropped.
export function AdminCreateInstructorPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [errors, setErrors] = useState<Record<string, Msg>>({});
  const [failure, setFailure] = useState<unknown>(null);
  const [submitting, setSubmitting] = useState(false);
  const [created, setCreated] = useState<CreateInstructorResponse | null>(null);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    setFailure(null);
    const clientErrors = validateInstructorForm({ fullName, email });
    setErrors(clientErrors);
    if (Object.keys(clientErrors).length > 0) {
      focusFirstInvalid(form);
      return;
    }
    setSubmitting(true);
    try {
      setCreated(await createInstructor({ fullName: fullName.trim(), email: email.trim() }));
      setFullName('');
      setEmail('');
    } catch (error) {
      if (error instanceof ApiError && error.status === 400 && Object.keys(error.fieldErrors).length > 0) {
        setErrors(serverFieldMsgs(error.fieldErrors));
        focusFirstInvalid(form);
      } else if (error instanceof ApiError && error.status === 409 && error.code === 'duplicate_account') {
        setErrors({ email: msg('val.duplicateAccount') });
        focusFirstInvalid(form);
      } else {
        setFailure(error);
      }
    } finally {
      setSubmitting(false);
    }
  };

  if (created) {
    return (
      <div className="page page-narrow">
        <h1>{t('admin.create.createdTitle')}</h1>
        <p dir="auto">
          <strong>{created.fullName}</strong> <span dir="ltr">({created.email})</span>
        </p>
        <TemporaryPasswordPanel password={created.temporaryPassword} expiresAt={created.temporaryPasswordExpiresAt} onDone={() => setCreated(null)} />
        <p className="button-row">
          <Link className="button button-secondary" to={`/admin/accounts/${created.id}`}>
            {t('admin.create.open')}
          </Link>
          <Link className="button button-secondary" to="/admin/accounts">
            {t('admin.detail.back')}
          </Link>
        </p>
      </div>
    );
  }

  return (
    <div className="page page-narrow">
      <h1>{t('admin.create.title')}</h1>
      <p className="muted">{t('admin.create.intro')}</p>
      <form className="card form" onSubmit={(event) => void handleSubmit(event)} noValidate>
        {failure != null && <Alert tone="error">{describeError(failure, i18n)}</Alert>}
        <FormField id="instructor-name" label={t('reg.fullName')} error={errors.fullName}>
          <input
            id="instructor-name"
            dir="auto"
            autoComplete="off"
            maxLength={LIMITS.fullNameMax + 20}
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
            aria-invalid={Boolean(errors.fullName)}
            aria-describedby={describedBy('instructor-name', errors.fullName)}
          />
        </FormField>
        <FormField id="instructor-email" label={t('reg.email')} error={errors.email}>
          <input
            id="instructor-email"
            type="email"
            dir="ltr"
            autoComplete="off"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            aria-invalid={Boolean(errors.email)}
            aria-describedby={describedBy('instructor-email', errors.email)}
          />
        </FormField>
        <div className="form-actions">
          <Link className="button button-secondary" to="/admin/accounts">
            {t('common.cancel')}
          </Link>
          <button type="submit" className="button" disabled={submitting}>
            {submitting ? t('common.saving') : t('admin.create.submit')}
          </button>
        </div>
      </form>
    </div>
  );
}

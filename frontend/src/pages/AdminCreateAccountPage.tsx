import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { createInstructor, createStudent, studentCreationSupported } from '../api/admin';
import { ApiError, describeError } from '../api/errors';
import { Alert } from '../components/Feedback';
import { FormField, describedBy } from '../components/FormField';
import { IdentityDocumentField } from '../components/IdentityDocumentField';
import { TemporaryPasswordPanel } from '../components/TemporaryPasswordPanel';
import { useI18n } from '../i18n/LanguageContext';
import { msg, resolveMsg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import type { CreateInstructorResponse } from '../types/api';
import type { TranslationKey } from '../i18n/en';
import { focusFirstInvalid } from '../utils/focus';
import { emptyIdentity, identityFormData, validateIdentity, type IdentityValues } from '../utils/identity';
import { LIMITS, validateInstructorForm } from '../utils/validation';

type NewAccountRole = 'Instructor' | 'Student';

const TEXT: Record<NewAccountRole, { title: TranslationKey; intro: TranslationKey; submit: TranslationKey; created: TranslationKey }> = {
  Instructor: { title: 'admin.create.title', intro: 'admin.create.intro', submit: 'admin.create.submit', created: 'admin.create.createdTitle' },
  Student: { title: 'admin.createStudent.title', intro: 'admin.createStudent.intro', submit: 'admin.createStudent.submit', created: 'admin.createStudent.createdTitle' },
};

// Creates an Instructor (POST /api/admin/instructors) or a Student account with exactly { fullName, email }; the server
// picks the role from the endpoint, never from the form. The 201 response carries the temporary password, which is shown
// once (kept in this component's state only) and then dropped. The backend has no student endpoint yet: see
// studentCreationSupported(). Until it has, a Student form is checked but nothing is sent and nothing is shown as created.
export function AdminCreateAccountPage({ role }: { role: NewAccountRole }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [errors, setErrors] = useState<Record<string, Msg>>({});
  const [failure, setFailure] = useState<unknown>(null);
  const [submitting, setSubmitting] = useState(false);
  const [created, setCreated] = useState<CreateInstructorResponse | null>(null);
  const [notSent, setNotSent] = useState(false);
  // Identity documents (students only). In memory only: never written to any storage, never logged.
  const [identity, setIdentity] = useState<IdentityValues>(emptyIdentity);
  const text = TEXT[role];
  const unavailable = role === 'Student' && !studentCreationSupported();
  const idBase = role.toLowerCase();

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    setFailure(null);
    setNotSent(false);
    const clientErrors = { ...validateInstructorForm({ fullName, email }), ...(role === 'Student' ? validateIdentity(identity) : {}) };
    setErrors(clientErrors);
    if (Object.keys(clientErrors).length > 0) {
      focusFirstInvalid(form);
      return;
    }
    if (unavailable) {
      setNotSent(true);
      return;
    }
    setSubmitting(true);
    try {
      const request = { fullName: fullName.trim(), email: email.trim() };
      const account = await (role === 'Student' ? createStudent(identityFormData(request.fullName, request.email, identity)) : createInstructor(request));
      if (account.role !== role) {
        // Never present an account as created with the wrong role.
        setFailure(new Error(`Expected a ${role} account but the server returned ${account.role}.`));
        return;
      }
      setCreated(account);
      setFullName('');
      setEmail('');
      setIdentity(emptyIdentity());
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
        <h1>{t(text.created)}</h1>
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
      <h1>{t(text.title)}</h1>
      <p className="muted">{t(text.intro)}</p>
      {unavailable && <Alert tone="info">{t('admin.createStudent.unavailable')}</Alert>}
      <form className="card form" onSubmit={(event) => void handleSubmit(event)} noValidate>
        {failure != null && <Alert tone="error">{describeError(failure, i18n)}</Alert>}
        {notSent && <Alert tone="info">{t('admin.createStudent.notSent')}</Alert>}
        <FormField id={`${idBase}-name`} label={t('reg.fullName')} error={errors.fullName}>
          <input
            id={`${idBase}-name`}
            dir="auto"
            autoComplete="off"
            maxLength={LIMITS.fullNameMax + 20}
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
            aria-invalid={Boolean(errors.fullName)}
            aria-describedby={describedBy(`${idBase}-name`, errors.fullName)}
          />
        </FormField>
        <FormField id={`${idBase}-email`} label={t('reg.email')} error={errors.email}>
          <input
            id={`${idBase}-email`}
            type="email"
            dir="ltr"
            autoComplete="off"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            aria-invalid={Boolean(errors.email)}
            aria-describedby={describedBy(`${idBase}-email`, errors.email)}
          />
        </FormField>
        {role === 'Student' && (
          <section className="id-section" aria-labelledby="identity-heading">
            <h2 id="identity-heading">
              {t('identity.title')} <span className="required-mark">{t('identity.mandatory')}</span>
            </h2>
            <p className="muted">{t('identity.intro')}</p>
            {errors.identity && (
              <p className="field-error" role="alert">
                {resolveMsg(errors.identity, i18n)}
              </p>
            )}
            <IdentityDocumentField
              id="national-id"
              title="identity.national"
              numberLabel="identity.nationalNumber"
              file={identity.nationalIdImage}
              number={identity.nationalIdNumber}
              imageError={errors.nationalIdImage}
              numberError={errors.nationalIdNumber}
              disabled={submitting}
              onFile={(nationalIdImage) => setIdentity((previous) => ({ ...previous, nationalIdImage }))}
              onNumber={(nationalIdNumber) => setIdentity((previous) => ({ ...previous, nationalIdNumber }))}
            />
            <IdentityDocumentField
              id="college-id"
              title="identity.college"
              numberLabel="identity.collegeNumber"
              file={identity.collegeIdImage}
              number={identity.collegeStudentId}
              imageError={errors.collegeIdImage}
              numberError={errors.collegeStudentId}
              disabled={submitting}
              onFile={(collegeIdImage) => setIdentity((previous) => ({ ...previous, collegeIdImage }))}
              onNumber={(collegeStudentId) => setIdentity((previous) => ({ ...previous, collegeStudentId }))}
            />
          </section>
        )}
        <div className="form-actions">
          <Link className="button button-secondary" to="/admin/accounts">
            {t('common.cancel')}
          </Link>
          <button type="submit" className="button" disabled={submitting}>
            {submitting ? t('common.saving') : t(text.submit)}
          </button>
        </div>
      </form>
    </div>
  );
}

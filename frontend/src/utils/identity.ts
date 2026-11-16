import { msg, type Msg } from '../i18n/serverMessages';

// The identity documents an administrator provides when creating a student: a National ID card (image plus the number on
// it) and/or a College ID card (image plus the student ID on it). At least one complete pair is required. These checks
// only help the administrator; the backend must validate the files and numbers again on its own.

export const ID_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const ID_IMAGE_ACCEPT = ID_IMAGE_TYPES.join(',');
export const ID_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
export const ID_IMAGE_MAX_MB = ID_IMAGE_MAX_BYTES / (1024 * 1024);
export const ID_NUMBER_MAX = 30;

export interface IdentityValues {
  nationalIdImage: File | null;
  nationalIdNumber: string;
  collegeIdImage: File | null;
  collegeStudentId: string;
}

export const emptyIdentity = (): IdentityValues => ({ nationalIdImage: null, nationalIdNumber: '', collegeIdImage: null, collegeStudentId: '' });

// null when the file is acceptable, otherwise why not (type and size only: the content is never read).
export function validateIdImage(file: File): Msg | null {
  if (!(ID_IMAGE_TYPES as readonly string[]).includes(file.type)) return msg('val.idImageType');
  if (file.size === 0) return msg('val.idImageEmpty');
  if (file.size > ID_IMAGE_MAX_BYTES) return msg('val.idImageSize', { max: ID_IMAGE_MAX_MB });
  return null;
}

// A document counts as selected as soon as its image or its number is filled in; a selected document needs both.
// With nothing selected at all, the section as a whole is reported. Keys: identity (the section), nationalIdImage,
// nationalIdNumber, collegeIdImage, collegeStudentId.
export function validateIdentity(values: IdentityValues): Record<string, Msg> {
  const errors: Record<string, Msg> = {};
  const check = (image: File | null, number: string, imageKey: string, numberKey: string, requiredNumber: Msg, requiredImage: Msg) => {
    const trimmed = number.trim();
    if (image) {
      const problem = validateIdImage(image);
      if (problem) errors[imageKey] = problem;
    } else if (trimmed) {
      errors[imageKey] = requiredImage;
    }
    if (image && !trimmed) errors[numberKey] = requiredNumber;
    else if (trimmed.length > ID_NUMBER_MAX) errors[numberKey] = msg('val.idNumberMax', { max: ID_NUMBER_MAX });
    else if (/[\p{Cc}\p{Cf}]/u.test(trimmed)) errors[numberKey] = msg('val.idNumberInvalid');
  };

  check(values.nationalIdImage, values.nationalIdNumber, 'nationalIdImage', 'nationalIdNumber', msg('val.nationalIdNumberRequired'), msg('val.nationalIdImageRequired'));
  check(values.collegeIdImage, values.collegeStudentId, 'collegeIdImage', 'collegeStudentId', msg('val.collegeIdNumberRequired'), msg('val.collegeIdImageRequired'));

  const anySelected = Boolean(values.nationalIdImage || values.nationalIdNumber.trim() || values.collegeIdImage || values.collegeStudentId.trim());
  if (!anySelected) errors.identity = msg('val.identityRequired');
  return errors;
}

// The multipart body for the future endpoint (docs/Frontend_Pending_Backend.md): only complete pairs are included.
export function identityFormData(fullName: string, email: string, values: IdentityValues): FormData {
  const form = new FormData();
  form.append('fullName', fullName);
  form.append('email', email);
  if (values.nationalIdImage) {
    form.append('nationalIdNumber', values.nationalIdNumber.trim());
    form.append('nationalIdImage', values.nationalIdImage, values.nationalIdImage.name);
  }
  if (values.collegeIdImage) {
    form.append('collegeStudentId', values.collegeStudentId.trim());
    form.append('collegeIdImage', values.collegeIdImage, values.collegeIdImage.name);
  }
  return form;
}

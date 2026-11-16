import { useEffect, useRef, useState } from 'react';
import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import { resolveMsg, type Msg } from '../i18n/serverMessages';
import { ID_IMAGE_ACCEPT, ID_IMAGE_MAX_MB, ID_NUMBER_MAX } from '../utils/identity';
import { FormField, describedBy } from './FormField';
import { Icon } from './Icon';

interface IdentityDocumentFieldProps {
  id: string;
  title: TranslationKey;
  numberLabel: TranslationKey;
  file: File | null;
  number: string;
  imageError?: Msg;
  numberError?: Msg;
  disabled?: boolean;
  onFile(file: File | null): void;
  onNumber(value: string): void;
}

// One identity document: an upload area with the file name and a preview (replace or remove), and the number printed on
// the card. The file lives in memory only; the preview is an object URL that is released when the file changes or the
// field goes away. The content of the file is never read, logged or stored.
export function IdentityDocumentField({ id, title, numberLabel, file, number, imageError, numberError, disabled, onFile, onNumber }: IdentityDocumentFieldProps) {
  const i18n = useI18n();
  const { t } = i18n;
  const input = useRef<HTMLInputElement>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!file) {
      setPreviewUrl(null);
      return undefined;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const pick = (chosen: File | undefined) => {
    if (chosen) onFile(chosen);
    if (input.current) input.current.value = ''; // so picking the same file again still counts as a change
  };

  const fileId = `${id}-image`;
  const numberId = `${id}-number`;

  return (
    <fieldset className="id-document">
      <legend>{t(title)}</legend>

      <div className={`field ${imageError ? 'field-invalid' : ''}`}>
        <span className="id-label" id={`${fileId}-label`}>
          {t('identity.image')}
        </span>
        <input
          ref={input}
          id={fileId}
          type="file"
          className="sr-only"
          accept={ID_IMAGE_ACCEPT}
          disabled={disabled}
          aria-labelledby={`${fileId}-label`}
          aria-invalid={Boolean(imageError)}
          aria-describedby={imageError ? `${fileId}-error` : `${fileId}-hint`}
          onChange={(event) => pick(event.target.files?.[0])}
        />
        {file ? (
          <div className="id-chosen">
            {previewUrl && <img className="id-preview" src={previewUrl} alt={t('identity.previewAlt', { name: file.name })} />}
            <div className="id-chosen-info">
              <p className="id-filename" dir="ltr">
                {file.name}
              </p>
              <div className="button-row">
                <button type="button" className="button button-secondary button-small" disabled={disabled} onClick={() => input.current?.click()}>
                  {t('identity.replace')}
                </button>
                <button type="button" className="button button-danger-outline button-small" disabled={disabled} onClick={() => onFile(null)}>
                  {t('identity.remove')}
                </button>
              </div>
            </div>
          </div>
        ) : (
          <button type="button" className="id-upload" disabled={disabled} onClick={() => input.current?.click()}>
            <Icon name="upload" size={22} />
            <span>{t('identity.choose')}</span>
          </button>
        )}
        {imageError ? (
          <p className="field-error" id={`${fileId}-error`}>
            {resolveMsg(imageError, i18n)}
          </p>
        ) : (
          <p className="field-hint" id={`${fileId}-hint`}>
            {t('identity.imageHint', { max: ID_IMAGE_MAX_MB })}
          </p>
        )}
      </div>

      <FormField id={numberId} label={t(numberLabel)} error={numberError}>
        <input
          id={numberId}
          dir="ltr"
          autoComplete="off"
          inputMode="text"
          maxLength={ID_NUMBER_MAX + 10}
          value={number}
          disabled={disabled}
          onChange={(event) => onNumber(event.target.value)}
          aria-invalid={Boolean(numberError)}
          aria-describedby={describedBy(numberId, numberError)}
        />
      </FormField>
    </fieldset>
  );
}

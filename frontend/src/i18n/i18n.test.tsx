import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { ApiError, describeError } from '../api/errors';
import { exam, jsonResponse, tokenResponse } from '../test/fixtures';
import { chooseLanguage, mockApi, renderApp } from '../test/helpers';
import { tokenStore } from '../auth/tokenStore';
import { formatDuration } from '../utils/dates';
import { ar } from './ar';
import { en } from './en';
import { localizeFieldErrors, localizeServerMessage } from './serverMessages';
import { createI18n, createTranslator, formatDateTime } from './translate';

const placeholders = (text: string) => [...text.matchAll(/\{(\w+)\}/g)].map((match) => match[1]).sort();

describe('dictionaries', () => {
  it('Arabic and English have exactly the same keys', () => {
    expect(Object.keys(ar).sort()).toEqual(Object.keys(en).sort());
  });

  it('no translation is empty and both languages use the same {placeholders}', () => {
    for (const key of Object.keys(en) as Array<keyof typeof en>) {
      expect(en[key].trim(), `en ${key}`).not.toBe('');
      expect(ar[key].trim(), `ar ${key}`).not.toBe('');
      expect(placeholders(ar[key]), `placeholders of ${key}`).toEqual(placeholders(en[key]));
    }
  });

  it('fills placeholders and leaves unknown ones visible', () => {
    expect(createTranslator('en')('pagination.page', { page: 2, count: 5 })).toBe('Page 2 of 5');
    expect(createTranslator('ar')('questions.editHeading', { n: 3 })).toBe('تعديل السؤال 3');
  });
});

describe('locale-aware formatting', () => {
  it('formats dates with Arabic or English month names (Western digits in both)', () => {
    const iso = '2030-01-15T12:00:00+00:00';
    expect(formatDateTime(iso, 'en')).toMatch(/Jan/);
    expect(formatDateTime(iso, 'ar')).toMatch(/يناير/);
    expect(formatDateTime(iso, 'ar')).toMatch(/2030/);
    expect(formatDateTime(null, 'ar')).toBe('—');
  });

  it('formats numbers and durations per language', () => {
    expect(createI18n('en', () => undefined).formatNumber(1234.5, { minimumFractionDigits: 2 })).toBe('1,234.50');
    expect(createI18n('ar', () => undefined).formatNumber(1234.5, { minimumFractionDigits: 2 })).toMatch(/1.234.50/);
    expect(formatDuration(90, createTranslator('en'))).toBe('1 h 30 min');
    expect(formatDuration(90, createTranslator('ar'))).toBe('1 ساعة و30 دقيقة');
    expect(formatDuration(45, createTranslator('ar'))).toBe('45 دقيقة');
  });
});

describe('translating backend messages', () => {
  const arabic = createI18n('ar', () => undefined);
  const english = createI18n('en', () => undefined);

  it('translates known messages and keeps numbers', () => {
    expect(localizeServerMessage('The exam has no questions.', arabic)).toBe(ar['srv.noQuestions']);
    expect(localizeServerMessage('Question 3 has no text.', arabic)).toBe('السؤال 3 ليس له نص.');
    expect(localizeServerMessage('An MCQ question can have at most 8 options.', arabic)).toContain('8');
    expect(localizeServerMessage("Passwords must have at least one digit ('0'-'9').", arabic)).toBe(ar['val.passwordDigit']);
    expect(localizeServerMessage('Start time must be a date and time with a time-zone offset, for example 2026-11-01T09:00:00Z.', arabic)).toBe(
      ar['val.startOffset'],
    );
  });

  it('shows unknown messages as sent, isolated left-to-right inside Arabic, plain in English', () => {
    expect(localizeServerMessage('Something new happened.', arabic)).toBe('⁦Something new happened.⁩');
    expect(localizeServerMessage('Something new happened.', english)).toBe('Something new happened.');
    expect(localizeServerMessage('The exam has no questions.', english)).toBe('The exam has no questions.');
  });

  it('keeps the backend field names while translating the messages', () => {
    const result = localizeFieldErrors(
      { 'options[1].text': ['Option text is required.'], password: ['Passwords must be at least 8 characters.', 'Passwords do not match.'] },
      arabic,
      { all: true },
    );
    expect(Object.keys(result)).toEqual(['options[1].text', 'password']);
    expect(result['options[1].text']).toBe(ar['val.optionRequired']);
    expect(result.password).toBe(`${ar['val.passwordMin'].replace('{n}', '8')} ${ar['val.passwordsMismatch']}`);
  });

  it('describeError translates by status and code, and never shows 5xx details', () => {
    const problem = (status: number, code: string | undefined, detail: string) => new ApiError('http', status, { status, code, detail });
    expect(describeError(problem(429, undefined, ''), arabic)).toBe(ar['error.tooMany']);
    expect(describeError(problem(500, undefined, 'System.Exception: secret'), arabic)).toBe(ar['error.server']);
    expect(describeError(problem(409, 'exam_not_publishable', 'The exam has no questions.'), arabic)).toBe(ar['srv.noQuestions']);
    expect(describeError(problem(403, 'account_locked', 'This account is temporarily locked after too many failed attempts. Try again later.'), arabic)).toBe(
      ar['srv.accountLocked'],
    );
    expect(describeError(new ApiError('network', 0), arabic)).toBe(ar['error.network']);
    expect(describeError(problem(404, 'exam_not_found', 'x'), english)).toBe(en['error.examNotFound']);
  });
});

describe('language switching in the running app', () => {
  function signInInstructor() {
    tokenStore.setFromTokenResponse(tokenResponse());
    return mockApi({
      'GET /api/exams': [() => jsonResponse(200, { items: [exam({ title: 'Midterm', startsAt: '2030-01-15T12:00:00+00:00', endsAt: '2030-01-15T13:30:00+00:00' })], page: 1, pageSize: 10, totalCount: 1 })],
    });
  }

  it('defaults to Arabic: <html lang="ar" dir="rtl"> on a first visit', async () => {
    signInInstructor();
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: ar['list.title'] })).toBeInTheDocument();
    expect(document.documentElement.lang).toBe('ar');
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('switches to English and back immediately, keeps the page and the session, and stores only the language code', async () => {
    signInInstructor();
    const user = userEvent.setup();
    renderApp('/exams');
    await screen.findByRole('heading', { name: ar['list.title'] });
    const toggle = screen.getByRole('group', { name: ar['lang.label'] });

    await user.click(within(toggle).getByRole('button', { name: 'English' }));

    expect(screen.getByRole('heading', { name: en['list.title'] })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Midterm' })).toBeInTheDocument(); // user content is untouched
    expect(document.documentElement.lang).toBe('en');
    expect(document.documentElement.dir).toBe('ltr');
    expect(window.localStorage.getItem('lang')).toBe('en');
    expect(window.localStorage.length).toBe(1);
    expect(tokenStore.getSession()).not.toBeNull();
    expect(JSON.stringify({ ...window.localStorage })).not.toMatch(/access-1|refresh-1/);

    await user.click(within(screen.getByRole('group', { name: en['lang.label'] })).getByRole('button', { name: 'العربية' }));
    expect(screen.getByRole('heading', { name: ar['list.title'] })).toBeInTheDocument();
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('remembers the stored language after a reload (a fresh render)', async () => {
    chooseLanguage('en');
    signInInstructor();
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: en['list.title'] })).toBeInTheDocument();
    expect(document.documentElement.lang).toBe('en');
    expect(document.documentElement.dir).toBe('ltr');
  });

  it('still works in Arabic when localStorage is unavailable', async () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    signInInstructor();
    const user = userEvent.setup();
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: ar['list.title'] })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'English' }));
    expect(screen.getByRole('heading', { name: en['list.title'] })).toBeInTheDocument(); // the choice works for this visit
  });

  it('formats the exam start in the active language', async () => {
    chooseLanguage('en');
    signInInstructor();
    const user = userEvent.setup();
    renderApp('/exams');
    await screen.findByRole('link', { name: 'Midterm' });
    const row = screen.getByRole('link', { name: 'Midterm' }).closest('tr')!;
    expect(within(row).getByText(/Jan/)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'العربية' }));
    expect(within(row).getByText(/يناير/)).toBeInTheDocument();
  });
});

// Read from disk: the test environment does not give the stylesheet's text through an import.
const css = readFileSync('src/styles.css', 'utf-8');

describe('right-to-left support in the stylesheet', () => {
  it('uses logical properties instead of physical left/right ones', () => {
    const physical = /(^|[\s{;])(margin-left|margin-right|padding-left|padding-right|border-left|border-right|left|right)\s*:|text-align:\s*(left|right)|float:\s*(left|right)/;
    const offending = css.split('\n').filter((line) => physical.test(line));
    expect(offending).toEqual([]);
  });

  it('mirrors direction-bearing arrows in right-to-left layouts', () => {
    expect(css).toMatch(/\[dir='rtl'\]\s+\.icon-flip/);
  });

  it('has an Arabic-capable font stack', () => {
    expect(css).toMatch(/--font:[^;]*(Tahoma|Noto Naskh Arabic|Noto Sans Arabic)/);
  });
});

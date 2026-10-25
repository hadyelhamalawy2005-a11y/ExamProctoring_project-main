import { describe, expect, it } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { callsTo, mockApi } from '../test/helpers';
import { importQuestions, previewQuestionImport } from './questionImport';

const PREVIEW = 'POST /api/questions/import/preview';

describe('previewQuestionImport', () => {
  it('uploads the file as multipart form data in the field "file" and lets the browser set the Content-Type', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const fetchMock = mockApi({ [PREVIEW]: [() => jsonResponse(200, { questions: [], issues: [] })] });
    const file = new File(['PK'], 'exam.docx');

    await previewQuestionImport(file);

    const [, init] = callsTo(fetchMock, PREVIEW)[0] as [string, RequestInit];
    expect((init.body as FormData).get('file')).toBeInstanceOf(File);
    expect(((init.body as FormData).get('file') as File).name).toBe('exam.docx');
    const headers = init.headers as Record<string, string>;
    expect(headers.Authorization).toBe('Bearer access-1');
    expect(Object.keys(headers).map((name) => name.toLowerCase())).not.toContain('content-type');
  });

  it('after an expired access token it refreshes once and uploads the same file again', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const fetchMock = mockApi({
      [PREVIEW]: [() => problem(401, 'token_invalid', 'A valid access token is required.'), () => jsonResponse(200, { questions: [], issues: [] })],
      'POST /api/auth/refresh': [() => jsonResponse(200, tokenResponse({ accessToken: 'access-2' }))],
    });

    await previewQuestionImport(new File(['PK'], 'exam.docx'));

    const calls = callsTo(fetchMock, PREVIEW) as Array<[string, RequestInit]>;
    expect(calls).toHaveLength(2);
    expect((calls[1][1].body as FormData).get('file')).toBeInstanceOf(File);
    expect((calls[1][1].headers as Record<string, string>).Authorization).toBe('Bearer access-2');
  });
});

describe('importQuestions', () => {
  it('posts the reviewed questions as JSON to the exam', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const fetchMock = mockApi({ 'POST /api/exams/e%201/questions/import': [() => jsonResponse(201, { items: [] })] });
    const question = { type: 'Essay' as const, text: 'Q?', marks: 1, modelAnswer: null, options: [] };

    await importQuestions('e 1', [question]);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('/api/exams/e%201/questions/import');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({ questions: [question] });
    expect((init.headers as Record<string, string>)['Content-Type']).toBe('application/json');
  });
});

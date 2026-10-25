import { render } from '@testing-library/react';
import type { ReactElement } from 'react';
import { MemoryRouter } from 'react-router-dom';
import { vi } from 'vitest';
import { AppRoutes } from '../App';
import { AuthProvider } from '../auth/AuthContext';
import { LanguageProvider } from '../i18n/LanguageContext';
import type { Lang } from '../i18n/translate';

type ResponseFactory = () => Response | Promise<Response>;

// Routes a mocked fetch by "METHOD /path" (the query string is ignored). Each route holds a queue of factories; the last
// one repeats. A factory may throw (for example a TypeError, like a network failure). Unknown routes fail the test.
export function mockApi(routes: Record<string, ResponseFactory[]>) {
  const queues = new Map(Object.entries(routes).map(([key, factories]) => [key, [...factories]]));
  const fetchMock = vi.fn((url: string, init?: RequestInit) => {
    const path = url.split('?')[0];
    const key = `${init?.method ?? 'GET'} ${path}`;
    const queue = queues.get(key);
    if (!queue || queue.length === 0) return Promise.reject(new Error(`Unexpected request: ${key}`));
    const factory = queue.length > 1 ? queue.shift()! : queue[0];
    try {
      return Promise.resolve(factory());
    } catch (error) {
      return Promise.reject(error);
    }
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

export const callsTo = (fetchMock: ReturnType<typeof mockApi>, key: string) =>
  fetchMock.mock.calls.filter(([url, init]) => `${(init as RequestInit | undefined)?.method ?? 'GET'} ${(url as string).split('?')[0]}` === key);

// Starts the UI in the given language by pre-setting the stored preference (Arabic is the default when nothing is stored).
export function chooseLanguage(lang: Lang) {
  window.localStorage.setItem('lang', lang);
}

export function renderWithProviders(ui: ReactElement, initialPath = '/') {
  return render(
    <LanguageProvider>
      <AuthProvider>
        <MemoryRouter initialEntries={[initialPath]}>{ui}</MemoryRouter>
      </AuthProvider>
    </LanguageProvider>,
  );
}

export const renderApp = (initialPath: string) => renderWithProviders(<AppRoutes />, initialPath);

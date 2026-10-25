import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../auth/AuthContext';
import { tokenStore } from '../auth/tokenStore';
import { problem, tokenResponse } from '../test/fixtures';
import { ChangePasswordPage } from './ChangePasswordPage';

describe('ChangePasswordPage', () => {
  it('shows a locked account (403 account_locked) as a message and keeps the user signed in', async () => {
    tokenStore.setFromTokenResponse(tokenResponse({ mustChangePassword: true }));
    const detail = 'This account is temporarily locked after too many failed attempts. Try again later.';
    const fetchMock = vi.fn().mockResolvedValue(problem(403, 'account_locked', detail));
    vi.stubGlobal('fetch', fetchMock);

    render(
      <AuthProvider>
        <MemoryRouter initialEntries={['/change-password']}>
          <Routes>
            <Route path="/change-password" element={<ChangePasswordPage />} />
            <Route path="/login" element={<p>Login page</p>} />
            <Route path="/exams" element={<p>Exam list</p>} />
          </Routes>
        </MemoryRouter>
      </AuthProvider>,
    );

    const user = userEvent.setup();
    await user.type(screen.getByLabelText(/Current/), 'Temp1234');
    await user.type(screen.getByLabelText('New password'), 'Newpass123');
    await user.type(screen.getByLabelText(/Repeat/), 'Newpass123');
    await user.click(screen.getByRole('button', { name: 'Change password' }));

    expect(await screen.findByRole('alert')).toHaveTextContent(detail);
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1));
    expect(screen.queryByText('Login page')).not.toBeInTheDocument();
    expect(tokenStore.getSession()).not.toBeNull();
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });
});

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { changePassword as changePasswordRequest, login as loginRequest, logout as logoutRequest } from '../api/auth';
import { refreshSession } from '../api/client';
import { tokenStore, type Session } from './tokenStore';

// 'unavailable': a stored session exists but the server could not answer the restore (network error, 429 or 5xx).
export type AuthStatus = 'loading' | 'signedIn' | 'signedOut' | 'unavailable';

interface AuthContextValue {
  status: AuthStatus;
  session: Session | null;
  restoreError: unknown;
  retryRestore(): void;
  signIn(email: string, password: string): Promise<Session>;
  changePassword(currentPassword: string, newPassword: string): Promise<Session>;
  signOut(): Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function initialStatus(): AuthStatus {
  if (tokenStore.getSession()) return 'signedIn';
  return tokenStore.getRefreshToken() ? 'loading' : 'signedOut';
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(() => tokenStore.getSession());
  const [status, setStatus] = useState<AuthStatus>(initialStatus);
  const [restoreError, setRestoreError] = useState<unknown>(null);

  useEffect(
    () =>
      tokenStore.subscribe((next) => {
        setSession(next);
        setStatus(next ? 'signedIn' : 'signedOut');
      }),
    [],
  );

  // After a page reload only the refresh token is left (the access token lived in memory): exchange it once.
  useEffect(() => {
    if (status !== 'loading') return;
    refreshSession()
      .then((ok) => setStatus(ok ? 'signedIn' : 'signedOut'))
      .catch((error: unknown) => {
        // A temporary failure: the stored refresh token was not rejected, so keep it and offer a retry.
        setRestoreError(error);
        setStatus('unavailable');
      });
  }, [status]);

  const retryRestore = useCallback(() => {
    setRestoreError(null);
    setStatus('loading');
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    const tokens = await loginRequest(email, password);
    tokenStore.setFromTokenResponse(tokens);
    return tokenStore.getSession()!;
  }, []);

  const changePassword = useCallback(async (currentPassword: string, newPassword: string) => {
    const tokens = await changePasswordRequest(currentPassword, newPassword);
    tokenStore.setFromTokenResponse(tokens);
    return tokenStore.getSession()!;
  }, []);

  const signOut = useCallback(async () => {
    const refreshToken = tokenStore.getRefreshToken();
    try {
      if (refreshToken && tokenStore.getSession()) await logoutRequest(refreshToken);
    } catch {
      // Signing out locally still matters even if the server could not be told.
    } finally {
      tokenStore.clear();
    }
  }, []);

  const value = useMemo(
    () => ({ status, session, restoreError, retryRestore, signIn, changePassword, signOut }),
    [status, session, restoreError, retryRestore, signIn, changePassword, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside <AuthProvider>.');
  return context;
}

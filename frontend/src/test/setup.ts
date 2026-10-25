import '@testing-library/jest-dom/vitest';
import { cleanup, configure } from '@testing-library/react';
import { afterEach } from 'vitest';
import { tokenStore } from '../auth/tokenStore';

// findBy*/waitFor wait up to 4 s (the default is 1 s), enough for a busy machine.
configure({ asyncUtilTimeout: 4000 });

afterEach(() => {
  cleanup();
  tokenStore.clear();
  tokenStore.dismissEndReason();
  window.sessionStorage.clear();
  window.localStorage.clear();
  document.documentElement.removeAttribute('lang');
  document.documentElement.removeAttribute('dir');
});

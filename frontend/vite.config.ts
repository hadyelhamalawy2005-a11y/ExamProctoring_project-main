/// <reference types="vitest/config" />
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// Development: the React dev server forwards /api calls to the backend (VITE_DEV_PROXY_TARGET), so the browser
// only talks to its own origin and the backend needs no CORS entry. Production builds call VITE_API_BASE_URL directly.
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '');
  // Default: the backend's "http" launch profile (src/ExamProctoring.Api/Properties/launchSettings.json). For the
  // "https" profile set VITE_DEV_PROXY_TARGET=https://localhost:7046 in .env.local.
  const proxyTarget = env.VITE_DEV_PROXY_TARGET || 'http://localhost:5168';

  return {
    plugins: [react()],
    server: {
      port: 5173,
      strictPort: true,
      proxy: {
        '/api': {
          target: proxyTarget,
          changeOrigin: true,
          // Only matters for an https target. The ASP.NET Core development certificate is trusted by Windows, not by
          // Node.js, so the local proxy skips the check; the browser still uses the dev server over its own origin.
          secure: env.VITE_DEV_PROXY_VERIFY_TLS === 'true',
        },
      },
    },
    test: {
      environment: 'jsdom',
      globals: true,
      setupFiles: ['./src/test/setup.ts'],
      // jsdom pages with many fields are slow on a busy machine; generous limits avoid false failures, not real ones.
      testTimeout: 20000,
      restoreMocks: true,
      unstubGlobals: true,
    },
  };
});

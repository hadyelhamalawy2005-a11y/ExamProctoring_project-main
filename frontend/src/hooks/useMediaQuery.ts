import { useEffect, useState } from 'react';

// True while the window matches a CSS media query. Where the browser has no matchMedia (the test environment) it is
// false, which is the phone layout.
export function useMediaQuery(query: string): boolean {
  const supported = typeof window !== 'undefined' && typeof window.matchMedia === 'function';
  const [matches, setMatches] = useState(() => (supported ? window.matchMedia(query).matches : false));

  useEffect(() => {
    if (!supported) return undefined;
    const list = window.matchMedia(query);
    const update = () => setMatches(list.matches);
    update();
    list.addEventListener('change', update);
    return () => list.removeEventListener('change', update);
  }, [query, supported]);

  return matches;
}

/** The width from which the sidebar replaces the bottom navigation. Keep in step with --breakpoint-wide in styles.css. */
export const WIDE_QUERY = '(min-width: 60rem)';

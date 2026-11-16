import { render, screen, within } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { Logo, LogoSymbol } from '../components/Logo';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { jsonResponse, tokenResponse } from '../test/fixtures';
import { chooseLanguage, mockApi, renderApp } from '../test/helpers';
import type { Role } from '../types/api';

// The brand identity applied to the app: the official colours, bundled fonts, the logo, and one shell for every role.

const tokens = readFileSync('src/brand/tokens.css', 'utf-8');
const styles = readFileSync('src/styles.css', 'utf-8');
const html = readFileSync('index.html', 'utf-8');
const signIn = (role: Role) => tokenStore.setFromTokenResponse(tokenResponse({ role }));

describe('design tokens', () => {
  it('carry the five colours the guidelines label with a HEX code', () => {
    expect(tokens).toMatch(/--brand-burgundy:\s*#7a1f2b/i);
    expect(tokens).toMatch(/--brand-berry:\s*#a83249/i);
    expect(tokens).toMatch(/--brand-gold:\s*#d7ad65/i);
    expect(tokens).toMatch(/--brand-charcoal:\s*#23242b/i);
    expect(tokens).toMatch(/--brand-offwhite:\s*#f8f6f2/i);
  });

  it('keep the brand palette apart from the semantic layer, so a dark theme only redefines the semantic layer', () => {
    // Components read semantic names (--surface, --text, --primary ...), which point at the palette.
    expect(tokens).toMatch(/--primary:\s*var\(--brand-burgundy\)/);
    expect(tokens).toMatch(/--bg:\s*var\(--brand-offwhite\)/);
    expect(tokens).toMatch(/--text:\s*var\(--brand-charcoal\)/);
  });

  it('are the only place that holds literal colours: the stylesheet uses tokens (white is the one exception)', () => {
    const withoutImages = styles.replace(/url\("[^"]*"\)/g, '');
    const literals = (withoutImages.match(/#[0-9a-fA-F]{3,8}\b/g) ?? []).filter((hex) => hex.toLowerCase() !== '#ffffff');
    expect(literals).toEqual([]);
  });

  it('do not name the palette inside components: no brand-* variable is used outside the tokens file', () => {
    expect(styles).not.toMatch(/var\(--brand-/);
    expect(styles).not.toMatch(/var\(--ref-/);
  });
});

describe('fonts', () => {
  it('are bundled with the app: no request goes to a font server', () => {
    expect(styles + tokens + html).not.toMatch(/fonts\.googleapis|fonts\.gstatic|use\.typekit|cdn\./i);
    const fonts = readFileSync('src/brand/fonts.ts', 'utf-8');
    for (const family of ['sora', 'plus-jakarta-sans', 'ibm-plex-sans-arabic', 'jetbrains-mono']) {
      expect(fonts).toContain(`@fontsource/${family}/`);
    }
  });

  it('use Sora for display, Plus Jakarta Sans for text, IBM Plex Sans Arabic for Arabic and JetBrains Mono for codes', () => {
    expect(tokens).toMatch(/--font-display:\s*'Sora'/);
    expect(tokens).toMatch(/--font-text:\s*'Plus Jakarta Sans'/);
    expect(tokens).toMatch(/--font-text:[^;]*'IBM Plex Sans Arabic'/);
    expect(tokens).toMatch(/--font-mono:\s*'JetBrains Mono'/);
  });
});

describe('the logo', () => {
  it('is an SVG with the accessible name Examora when it carries a label, and is hidden otherwise', () => {
    const { container } = render(
      <>
        <Logo label="Examora" />
        <Logo />
      </>,
    );
    expect(screen.getAllByRole('img', { name: 'Examora' })).toHaveLength(1);
    expect(container.querySelectorAll('svg[aria-hidden="true"]')).toHaveLength(1);
  });

  it('draws the shield with the gold fold, and the wordmark only in the lockup', () => {
    const { container: symbol } = render(<LogoSymbol size={48} />);
    const { container: lockup } = render(<Logo />);
    expect(symbol.querySelectorAll('path')).toHaveLength(2); // shield (with knock-outs) + fold
    expect(lockup.querySelectorAll('path')).toHaveLength(3); // + wordmark
    expect(symbol.querySelector('path[fill="var(--brand-logo-fold, #D7AD65)"]')).not.toBeNull();
  });

  it('switches to the small-size symbol at 28 px and below', () => {
    const big = render(<LogoSymbol size={48} />).container.querySelector('path')!.getAttribute('d');
    const small = render(<LogoSymbol size={24} />).container.querySelector('path')!.getAttribute('d');
    expect(small).not.toEqual(big);
    expect(big!.length).toBeGreaterThan(small!.length); // one exam line instead of two
  });

  it('has a reversed (white) and a single-colour version for dark and one-colour grounds', () => {
    const reversed = render(<LogoSymbol tone="reversed" />).container;
    expect(reversed.querySelector('path')!.getAttribute('fill')).toBe('#FFFFFF');
    const mono = render(<LogoSymbol tone="mono" />).container;
    expect(mono.querySelectorAll('path[fill="currentColor"]')).toHaveLength(2);
  });

  it('is the page icon', () => {
    expect(html).toContain('rel="icon"');
    expect(html).toContain('/favicon.svg');
    expect(html).toContain('<title>Examora');
  });
});

// The wide layout is the sidebar; the compact one is the bottom bar. The window width is chosen with matchMedia.
function setWide(wide: boolean) {
  vi.stubGlobal('matchMedia', (query: string) => ({
    matches: wide,
    media: query,
    addEventListener: () => undefined,
    removeEventListener: () => undefined,
  }));
}

const ROLE_HOME: Record<Role, string> = { Admin: '/admin/accounts', Instructor: '/instructor', Student: '/student' };
// What each role sees in its navigation (the bottom bar shows the profile as a tab, the sidebar as the person at its foot).
const ITEMS: Record<Role, string[]> = {
  Admin: [en['nav.accounts'], en['nav.newInstructor'], en['nav.newStudent']],
  Instructor: [en['nav.home'], en['nav.exams'], en['nav.import'], en['nav.incidents']],
  Student: [en['nav.home'], en['nav.exams'], en['nav.results']],
};

describe('one shell for every role', () => {
  beforeEach(() => {
    chooseLanguage('en');
    mockApi({
      'GET /api/admin/accounts': [() => jsonResponse(200, { items: [], page: 1, pageSize: 20, totalCount: 0 })],
      'GET /api/exams': [() => jsonResponse(200, { items: [], page: 1, pageSize: 1, totalCount: 0 })],
    });
  });

  for (const role of ['Admin', 'Instructor', 'Student'] as const) {
    it(`${role}: a sidebar with the logo, the role’s navigation and the signed-in person on a wide window`, async () => {
      setWide(true);
      signIn(role);
      renderApp(ROLE_HOME[role]);
      const nav = await screen.findByRole('navigation', { name: en['nav.main'] });
      expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(ITEMS[role]);
      expect(screen.getByRole('link', { name: 'Examora' })).toHaveAttribute('href', ROLE_HOME[role]);
      // The person at the foot of the sidebar opens the profile.
      expect(screen.getByRole('link', { name: en['nav.profile'] })).toHaveAttribute('href', '/profile');
      expect(within(screen.getByRole('complementary')).getByText(en[`role.${role}`])).toBeInTheDocument();
      // The current screen is marked in the navigation.
      expect(within(nav).getAllByRole('link').filter((link) => link.getAttribute('aria-current') === 'page')).toHaveLength(1);
    });

    it(`${role}: the same destinations in a bottom bar on a phone or tablet, with the profile as the last tab`, async () => {
      setWide(false);
      signIn(role);
      renderApp(ROLE_HOME[role]);
      const nav = await screen.findByRole('navigation', { name: en['nav.main'] });
      const tabs = within(nav).getAllByRole('link');
      expect(tabs).toHaveLength(ITEMS[role].length + 1);
      expect(tabs.at(-1)).toHaveAttribute('href', '/profile');
      expect(tabs.map((tab) => tab.getAttribute('href'))).toEqual(expect.arrayContaining(ITEMS[role].map(() => expect.any(String))));
    });
  }

  it('only one of the two navigations is on the page at a time', async () => {
    setWide(true);
    signIn('Instructor');
    renderApp('/instructor');
    expect(await screen.findAllByRole('navigation', { name: en['nav.main'] })).toHaveLength(1);
  });

  it('works in Arabic, right to left, with the same navigation', async () => {
    chooseLanguage('ar');
    setWide(true);
    signIn('Instructor');
    renderApp('/instructor');
    const nav = await screen.findByRole('navigation', { name: ar['nav.main'] });
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual([ar['nav.home'], ar['nav.exams'], ar['nav.import'], ar['nav.incidents']]);
    expect(document.documentElement).toHaveAttribute('dir', 'rtl');
  });
});

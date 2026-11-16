# Examora brand identity in the React app

Source: `Examora-Brand-Identity.pdf` (34 pages, "Crest", November 2026). This page says where each part of it lives in
`frontend/` and what is a decision of ours rather than the guidelines'.

## Files

| Part | File |
|---|---|
| Design tokens (colour, type, space, radius, shadow) | `src/brand/tokens.css` |
| Bundled fonts | `src/brand/fonts.ts` (npm `@fontsource/*`, nothing is fetched at run time) |
| Logo (SVG components) | `src/components/Logo.tsx` (`Logo`, `LogoSymbol`) |
| Logo files for download, favicon | `public/favicon.svg`, `public/brand/*.svg` |
| Line icons | `src/components/Icon.tsx` |
| App shell: sidebar, title bar, bottom navigation | `src/components/RoleLayout.tsx` |
| Pre-sign-in frame (brand panel + card) | `src/components/AuthShell.tsx` |
| All component styles | `src/styles.css` |
| Tests of the above | `src/brand/brand.test.tsx` |

## Colour

The five colours labelled in the guidelines are authoritative: burgundy `#7A1F2B`, berry `#A83249`, gold `#D7AD65`,
charcoal `#23242B`, warm off-white `#F8F6F2`. Everything else in `tokens.css` under "Reference values" was read from the
pixels of the guidelines' colour page and product screens (hover, press, soft fills, lines, the status colours, muted
text `#5E5D66`) because the PDF does not print their codes.

Tokens come in layers. Components use only the **semantic** layer (`--surface`, `--text`, `--primary`, `--line`,
`--status-*` ...), never `--brand-*` or a literal colour (a test enforces this). That is what keeps dark mode cheap:

```css
/* Later: redefine the semantic layer only. No component rule changes. */
:root[data-theme='dark'] {
  color-scheme: dark;
  --bg: #16161b;
  --surface: #1f2027;
  /* ... */
}
```

The guidelines show dark values on the student dashboard (page `#16161B`, surface `#1F2027`, nav active `#3A1C22`,
CTA `#B8405A`, ring `#E07D8C`) which can seed that block. Dark mode is **not** implemented yet by decision.

Deviation: form fields use `--field-border` (`#8F897E`, 3.4:1 on white) instead of the lighter line colour drawn in the
guidelines (1.7:1), so their edge meets WCAG's 3:1 for UI components.

## Typography

Sora for headings and display, Plus Jakarta Sans for text and UI, IBM Plex Sans Arabic for Arabic, JetBrains Mono for
overlines, codes and labels. The `:lang(ar)` rules drop letter-spacing and upper-casing, which do not apply to Arabic.

## Logo

Drawn as SVG from the geometry on guidelines page 6: 48-unit grid, shield 38 × 41 with r5 top corners, a 45° fold of
14 units (the only gold), exam lines and check as true knock-outs with one 3.6-unit stroke.

- The **symbol** is constructed from that geometry and checked against the PDF image by overlay.
- The **wordmark** has no font to reuse, so it was **traced** from the logo image in the PDF (the letterforms are
  faithful; corners are very slightly softer than the original at very large sizes). If the designer can supply the
  original SVG/vector wordmark, replace `WORDMARK` in `Logo.tsx` and the files in `public/brand/`.
- Proportions: wordmark cap height 47% and gap 26% of the 48-unit grid. Clear space = the fold width. Minimum
  24 px symbol height (horizontal). The stacked lockup is not drawn (no screen uses it). At 28 px and below the **small-size symbol** (one exam line, heavier
  strokes) is used, as on guidelines pages 7 and 8.
- Tones: `color` (primary), `reversed` (white on burgundy/charcoal, gold fold kept), `mono` (one colour).

## Layout

One shell for Admin, Instructor and Student. From 60 rem (960 px) it is the sidebar layout of the guidelines' product
screens: logo, the role's navigation, the signed-in person at the foot (opens the profile), and a title bar. Below
60 rem the same destinations become a bottom navigation bar under a compact title bar. The width is read with
`matchMedia` (`hooks/useMediaQuery.ts`), so only one navigation is ever in the page. Right-to-left mirrors the whole
layout; only logical CSS properties are used (a test enforces this).

## Graphic devices

The fold (`.fold`, one per view), the answer-sheet pattern (`.pattern`, burgundy panels), exam-line data bars (`.bar`),
feature tiles (`.feature-tile`, 44 px, soft fill, never multicolour), overlines (`.overline`).

## Not applied (outside the web app)

Marketing creatives, email signature, certificate, report template, pricing and homepage layouts (guidelines pages
17–20 and 27–33). The app has no such screens; they were read for logo and colour usage only.

import { render, screen, within } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { beforeEach, describe, expect, it } from 'vitest';
import { chooseLanguage, renderWithProviders } from '../test/helpers';
import { emptyCodeQuestion } from '../types/code';
import { CodeQuestionForm } from './CodeQuestionForm';
import { Icon } from './Icon';

// Final review fixes for the code question editor (right-to-left language names, labels) and the key icon.

const css = readFileSync('src/styles.css', 'utf-8');

describe('code question editor in Arabic', () => {
  beforeEach(() => chooseLanguage('ar'));

  it('keeps programming-language names left to right, so C++ is not shown as ++C', () => {
    renderWithProviders(<CodeQuestionForm question={emptyCodeQuestion('cq1')} onSubmit={() => undefined} onCancel={() => undefined} />);
    const checkbox = screen.getByRole('checkbox', { name: 'C++' });
    const name = within(checkbox.closest('label')!).getByText('C++');
    expect(name.tagName).toBe('BDI');
    expect(name).toHaveAttribute('dir', 'ltr');
    expect(screen.getAllByRole('combobox').find((select) => select.id.endsWith('-deflang'))).toHaveAttribute('dir', 'ltr');
  });
});

describe('stylesheet', () => {
  it('labels the "default" pickers of the code question like every other field, and spaces the code question list', () => {
    expect(css).toMatch(/\.options-editor > label:not\(\.check\)\s*\{[^}]*font-weight:\s*600/);
    expect(css).toMatch(/\.code-questions\s*\{[^}]*margin-top:\s*var\(--space-5\)/);
  });

  it('does not tint the active code line like an answered or selected item', () => {
    expect(css).toMatch(/\.cm-activeLine\s*\{\s*background:\s*var\(--surface-sunken\)/);
  });
});

describe('key icon', () => {
  it('is drawn as a ring and a shaft with teeth: three paths, not a single blob', () => {
    const { container } = render(<Icon name="key" />);
    expect(container.querySelectorAll('path')).toHaveLength(3);
  });
});

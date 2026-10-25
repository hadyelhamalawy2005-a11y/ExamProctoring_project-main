import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { LanguageProvider } from '../i18n/LanguageContext';
import { ar } from '../i18n/ar';
import { tokenStore } from '../auth/tokenStore';
import { exam, problem, tokenResponse } from '../test/fixtures';
import { mockApi } from '../test/helpers';
import { ConfirmDialog } from './ConfirmDialog';
import { ExamActions } from './ExamActions';

function Harness({ onConfirm = () => undefined }: { onConfirm?: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        Open dialog
      </button>
      <ConfirmDialog open={open} title="Delete it?" confirmLabel="Delete" tone="danger" onConfirm={onConfirm} onCancel={() => setOpen(false)}>
        <p>Really?</p>
      </ConfirmDialog>
    </>
  );
}

describe('ConfirmDialog accessibility', () => {
  it('moves focus into the dialog, names it by its title, and returns focus to the opener on Escape', async () => {
    const user = userEvent.setup();
    render(<Harness />);
    const opener = screen.getByRole('button', { name: 'Open dialog' });

    await user.click(opener);

    const dialog = screen.getByRole('dialog', { name: 'Delete it?' });
    expect(dialog).toHaveAttribute('aria-modal', 'true');
    expect(screen.getByRole('button', { name: 'Keep' })).toHaveFocus();

    await user.keyboard('{Escape}');

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(opener).toHaveFocus();
  });

  it('keeps Tab and Shift+Tab inside the dialog', async () => {
    const user = userEvent.setup();
    render(<Harness />);
    await user.click(screen.getByRole('button', { name: 'Open dialog' }));
    const keep = screen.getByRole('button', { name: 'Keep' });
    const confirm = screen.getByRole('button', { name: 'Delete' });

    await user.tab();
    expect(confirm).toHaveFocus();
    await user.tab(); // past the last control: back to the first
    expect(keep).toHaveFocus();
    await user.tab({ shift: true }); // before the first control: to the last
    expect(confirm).toHaveFocus();
  });

  it('does not take focus back to "Keep" when the parent re-renders while it is open', async () => {
    const user = userEvent.setup();
    const { rerender } = render(<Harness />);
    await user.click(screen.getByRole('button', { name: 'Open dialog' }));
    await user.tab(); // focus the confirm button
    const confirm = screen.getByRole('button', { name: 'Delete' });
    expect(confirm).toHaveFocus();

    rerender(<Harness onConfirm={vi.fn()} />);

    expect(confirm).toHaveFocus();
  });
});

describe('lifecycle dialogs in Arabic', () => {
  it('shows the Arabic confirmation and a translated server refusal', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockApi({ 'POST /api/exams/e1/publish': [() => problem(409, 'exam_not_publishable', 'The exam has no questions.')] });
    const user = userEvent.setup();
    const onStale = vi.fn();
    render(
      <LanguageProvider>
        <MemoryRouter>
          <ExamActions exam={exam()} onChanged={vi.fn()} onDeleted={vi.fn()} onStale={onStale} />
        </MemoryRouter>
      </LanguageProvider>,
    );

    await user.click(screen.getByRole('button', { name: ar['actions.publish'] }));
    expect(screen.getByRole('dialog', { name: ar['actions.publishTitle'] })).toHaveTextContent(ar['actions.publishBody']);
    await user.click(screen.getAllByRole('button', { name: ar['actions.publish'] }).at(-1)!);

    expect(await screen.findByRole('alert')).toHaveTextContent(ar['srv.noQuestions']);
    expect(onStale).toHaveBeenCalledTimes(1);
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('marks cancelling as irreversible in the Arabic dialog and keeps the exam when the user chooses Keep', async () => {
    const fetchMock = mockApi({});
    const user = userEvent.setup();
    render(
      <LanguageProvider>
        <MemoryRouter>
          <ExamActions exam={exam({ status: 'Published' })} onChanged={vi.fn()} onDeleted={vi.fn()} onStale={vi.fn()} />
        </MemoryRouter>
      </LanguageProvider>,
    );

    await user.click(screen.getByRole('button', { name: ar['actions.cancelExam'] }));
    expect(screen.getByRole('dialog')).toHaveTextContent('لا يمكن التراجع');
    await user.click(screen.getByRole('button', { name: ar['common.keep'] }));

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

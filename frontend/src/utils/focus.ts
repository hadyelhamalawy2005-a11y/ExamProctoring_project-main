// After a failed submit, moves keyboard and screen-reader focus to the first field marked aria-invalid, so the user
// lands on the problem (its message is linked through aria-describedby). Runs after React has rendered the errors.
export function focusFirstInvalid(form: ParentNode | null): void {
  window.setTimeout(() => {
    form?.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus();
  }, 0);
}

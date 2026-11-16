import { autocompletion, closeBrackets, closeBracketsKeymap, completionKeymap } from '@codemirror/autocomplete';
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import { cpp } from '@codemirror/lang-cpp';
import { java } from '@codemirror/lang-java';
import { javascript } from '@codemirror/lang-javascript';
import { python } from '@codemirror/lang-python';
import { bracketMatching, defaultHighlightStyle, indentOnInput, indentUnit, syntaxHighlighting } from '@codemirror/language';
import { Compartment, EditorState, type Extension } from '@codemirror/state';
import { EditorView, drawSelection, highlightActiveLine, keymap, lineNumbers } from '@codemirror/view';
import { useEffect, useRef } from 'react';
import { INDENT_SIZES, type CodeLanguageId } from '../types/code';

interface CodeEditorProps {
  value: string;
  onChange?(value: string): void;
  language: CodeLanguageId;
  autocomplete: boolean;
  readOnly?: boolean;
  ariaLabel: string;
}

const languageExtension = (language: CodeLanguageId): Extension => {
  switch (language) {
    case 'java':
      return java();
    case 'c':
    case 'cpp':
      return cpp();
    case 'python':
      return python();
    case 'javascript':
      return javascript();
  }
};

// Indentation follows the language (see INDENT_SIZES); it is never a setting the user picks.
const indentExtension = (language: CodeLanguageId): Extension => {
  const size = INDENT_SIZES[language];
  return [indentUnit.of(' '.repeat(size)), EditorState.tabSize.of(size)];
};

// A real CodeMirror 6 editor: syntax highlighting and indentation per language, optional auto-completion, and the
// the standard key bindings. Changing a setting reconfigures the editor without losing the text or the cursor.
// Callers that must not carry text (or undo history) across a language change give the editor a key per language.
// It does not run or check the code.
export default function CodeEditor({ value, onChange, language, autocomplete, readOnly = false, ariaLabel }: CodeEditorProps) {
  const host = useRef<HTMLDivElement>(null);
  const view = useRef<EditorView | null>(null);
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  const compartments = useRef({
    language: new Compartment(),
    indent: new Compartment(),
    complete: new Compartment(),
    readOnly: new Compartment(),
  });

  useEffect(() => {
    if (!host.current) return;
    const c = compartments.current;
    const editor = new EditorView({
      parent: host.current,
      state: EditorState.create({
        doc: value,
        extensions: [
          lineNumbers(),
          history(),
          drawSelection(),
          highlightActiveLine(),
          indentOnInput(),
          bracketMatching(),
          closeBrackets(),
          syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
          keymap.of([...closeBracketsKeymap, ...defaultKeymap, ...historyKeymap, ...completionKeymap, indentWithTab]),
          c.language.of(languageExtension(language)),
          c.indent.of(indentExtension(language)),
          c.complete.of(autocomplete ? autocompletion() : []),
          c.readOnly.of(EditorState.readOnly.of(readOnly)),
          EditorView.contentAttributes.of({ 'aria-label': ariaLabel, spellcheck: 'false' }),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) onChangeRef.current?.(update.state.doc.toString());
          }),
        ],
      }),
    });
    view.current = editor;
    return () => {
      editor.destroy();
      view.current = null;
    };
    // The editor is created once; the effects below reconfigure it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    view.current?.dispatch({
      effects: [
        compartments.current.language.reconfigure(languageExtension(language)),
        compartments.current.indent.reconfigure(indentExtension(language)),
      ],
    });
  }, [language]);

  useEffect(() => {
    view.current?.dispatch({ effects: compartments.current.complete.reconfigure(autocomplete ? autocompletion() : []) });
  }, [autocomplete]);

  useEffect(() => {
    view.current?.dispatch({ effects: compartments.current.readOnly.reconfigure(EditorState.readOnly.of(readOnly)) });
  }, [readOnly]);

  // The text changed from outside (for example a reset): replace it only when it really differs.
  useEffect(() => {
    const editor = view.current;
    if (editor && editor.state.doc.toString() !== value) {
      editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: value } });
    }
  }, [value]);

  return <div className="code-editor-host" ref={host} data-testid="code-editor" />;
}

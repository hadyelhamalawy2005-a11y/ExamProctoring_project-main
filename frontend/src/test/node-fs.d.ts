// Minimal typing for the one Node function the stylesheet test uses (the project does not install @types/node).
declare module 'node:fs' {
  export function readFileSync(path: URL | string, encoding: 'utf-8'): string;
}

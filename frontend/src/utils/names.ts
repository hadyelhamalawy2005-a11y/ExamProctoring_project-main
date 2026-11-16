// "Layla Mansour" -> "LM"; one name -> its first letter. Works for Arabic names too (the first letter of each word).
export function initialsOf(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean);
  return words
    .slice(0, 2)
    .map((word) => Array.from(word)[0])
    .join('')
    .toUpperCase();
}

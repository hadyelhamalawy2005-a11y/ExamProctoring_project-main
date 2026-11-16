import { describe, expect, it } from 'vitest';
import { distributeMarks, parseMarks, sumMarks, validatePlan } from './marks';

describe('distributeMarks', () => {
  it('splits an exact total equally', () => {
    expect(distributeMarks(20, 10)).toEqual(Array(10).fill(2));
  });

  it('supports decimal marks', () => {
    expect(distributeMarks(10, 4)).toEqual([2.5, 2.5, 2.5, 2.5]);
  });

  it('always adds up to the total, giving the extra hundredths to the first questions', () => {
    const parts = distributeMarks(10, 3)!;
    expect(parts).toEqual([3.34, 3.33, 3.33]);
    expect(sumMarks(parts)).toBe(10);
  });

  it('adds up exactly for awkward totals and counts', () => {
    for (const [total, count] of [[0.1, 7], [100, 3], [33.33, 9], [7.77, 5], [19.99, 13]] as const) {
      const parts = distributeMarks(total, count)!;
      expect(parts).toHaveLength(count);
      expect(sumMarks(parts)).toBe(total);
      expect(Math.max(...parts) - Math.min(...parts)).toBeLessThanOrEqual(0.01 + 1e-9);
    }
  });

  it('refuses the impossible: no questions, or less than 0.01 each', () => {
    expect(distributeMarks(10, 0)).toBeNull();
    expect(distributeMarks(0.05, 6)).toBeNull();
    expect(distributeMarks(Number.NaN, 2)).toBeNull();
  });
});

describe('parseMarks', () => {
  it('accepts plain decimals and a comma', () => {
    expect(parseMarks('2.5')).toBe(2.5);
    expect(parseMarks(' 3,25 ')).toBe(3.25);
  });
  it('rejects text, negatives, and exponents', () => {
    for (const bad of ['', 'abc', '-1', '1e3', '1.2.3']) expect(parseMarks(bad)).toBeNull();
  });
});

describe('validatePlan', () => {
  it('passes when the marks add up to the total', () => {
    expect(validatePlan('20', ['10', '5', '5']).problem).toBeNull();
    expect(validatePlan('10', ['3.34', '3.33', '3.33']).problem).toBeNull();
  });
  it('reports each kind of problem', () => {
    expect(validatePlan('', ['1']).problem).toBe('totalRequired');
    expect(validatePlan('0', ['1']).problem).toBe('totalInvalid');
    expect(validatePlan('1.234', ['1']).problem).toBe('totalInvalid');
    expect(validatePlan('0.01', ['1', '1']).problem).toBe('tooManyQuestions');
    expect(validatePlan('10', ['5', 'x'])).toEqual({ problem: 'markInvalid', index: 1 });
    expect(validatePlan('10', ['5', '0'])).toEqual({ problem: 'markInvalid', index: 1 });
    expect(validatePlan('10', ['5', '4']).problem).toBe('sumMismatch');
  });
});

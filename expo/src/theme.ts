import { useCSSVariable } from 'uniwind';
import type { SurveyStatus } from './contract/contract';

// Step 2: the colors live in global.css (light and dark). Screens use classNames;
// this hook is for the few props that take a color value, not a className
// (a tab bar's tint, a placeholder, the map's markers).
const NAMES = ['--color-background', '--color-surface', '--color-on-surface', '--color-muted', '--color-border', '--color-primary', '--color-on-primary', '--color-error'] as const;

export type Colors = {
  background: string;
  card: string;
  text: string;
  muted: string;
  border: string;
  primary: string;
  onPrimary: string;
  error: string;
};

/** The theme's colors as values; they follow the system's light or dark mode. */
export function useColors(): Colors {
  const [background, card, text, muted, border, primary, onPrimary, error] = useCSSVariable([...NAMES]).map(String);
  return { background, card, text, muted, border, primary, onPrimary, error };
}

export const statusLabel: Record<SurveyStatus, string> = {
  not_started: 'Not started',
  in_progress: 'In progress',
  submitted: 'Submitted',
  approved: 'Approved',
  needs_rework: 'Needs rework',
};

// Whole class names only: Uniwind finds classes in the source at build time,
// so `bg-${name}-bg` built from pieces would never be generated.
// box + text: a chip; pin: the strong color, for a dot on the map.
export const statusClass: Record<SurveyStatus, { box: string; text: string; pin: string }> = {
  not_started: { box: 'bg-todo-bg', text: 'text-todo', pin: 'bg-todo' },
  in_progress: { box: 'bg-progress-bg', text: 'text-progress', pin: 'bg-progress' },
  submitted: { box: 'bg-done-bg', text: 'text-done', pin: 'bg-done' },
  approved: { box: 'bg-done-bg', text: 'text-done', pin: 'bg-done' },
  needs_rework: { box: 'bg-rework-bg', text: 'text-rework', pin: 'bg-rework' },
};

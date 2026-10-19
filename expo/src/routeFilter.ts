import type { RouteStop, StopStatus } from './contract/contract';

export type StopFilter = 'all' | StopStatus;

export const STOP_FILTERS: readonly { value: StopFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'todo', label: 'To do' },
  { value: 'done', label: 'Done' },
  { value: 'skipped', label: 'Skipped' },
];

/** The stops a filter keeps, in route order. A pure function: no React here. */
export function filterStops(stops: readonly RouteStop[], filter: StopFilter): RouteStop[] {
  return stops
    .filter((s) => filter === 'all' || s.status === filter)
    .sort((a, b) => a.order - b.order);
}

/** What to say when the filter leaves nothing. */
export function emptyText(filter: StopFilter): string {
  const label = STOP_FILTERS.find((f) => f.value === filter)?.label ?? '';
  return `No ${label.toLowerCase()} stops on this route.`;
}

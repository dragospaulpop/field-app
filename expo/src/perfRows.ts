// Week 6, step 7: made-up survey rows for the performance test. Deterministic
// (the same rows on every run and in both stacks), so two runs compare.
export type PerfRow = { id: string; street: string; entrance: string; stories: number; flats: number };

const STREETS = ['Strada Lipscani', 'Bulevardul Unirii', 'Calea Victoriei', 'Strada Franceză', 'Șoseaua Ștefan cel Mare'];

export function makeRows(n: number): PerfRow[] {
  return Array.from({ length: n }, (_, i) => ({
    id: `perf-${i}`,
    street: `${STREETS[i % STREETS.length]} ${1 + (i % 120)}`,
    entrance: `Sc. ${String.fromCharCode(65 + (i % 6))}`,
    stories: 4 + (i % 7),
    flats: 10 + ((i * 7) % 60),
  }));
}

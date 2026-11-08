import { retryDelay } from '../src/photoQueue';

// Week 5's photo queue: only its backoff rule is tested here, so its storage is not loaded.
jest.mock('../src/db/db', () => ({ db: {} }));
jest.mock('../src/supabase', () => ({ supabase: {} }));
jest.mock('drizzle-orm/expo-sqlite', () => ({ useLiveQuery: jest.fn() }));
jest.mock('expo-sqlite/kv-store', () => ({ getItemSync: jest.fn(), setItemSync: jest.fn() }));
jest.mock('expo-network', () => ({}));

describe('retryDelay (full jitter)', () => {
  test('the window doubles: 2 s, 4 s, 8 s … times the random factor', () => {
    expect(retryDelay(0, () => 1)).toBe(2_000);
    expect(retryDelay(1, () => 1)).toBe(4_000);
    expect(retryDelay(3, () => 0.5)).toBe(8_000);
  });

  test('never more than the cap of 5 minutes', () => {
    expect(retryDelay(20, () => 1)).toBe(300_000);
  });

  test('anywhere from 0: that is what spreads the phones out', () => {
    expect(retryDelay(4, () => 0)).toBe(0);
  });
});

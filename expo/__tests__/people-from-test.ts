import { peopleFrom } from '../src/realtime';

jest.mock('../src/supabase', () => ({ supabase: {} }));
jest.mock('../src/auth', () => ({ currentUser: () => null }));

const ana = { userId: 'u-ana', email: 'ana@field.test' };
const bob = { userId: 'u-bob', email: 'bob@field.test' };

describe('peopleFrom (presence state to people)', () => {
  test('one person per userId, however many presence keys', () => {
    const state = {
      key1: [{ ...ana, since: '2026-11-08T09:53:30.000Z' }],
      key2: [{ ...bob, since: '2026-11-08T09:53:47.000Z' }],
      key3: [{ ...ana, since: '2026-11-08T09:50:00.000Z' }], // Ana's second device
    };
    expect(peopleFrom(state)).toEqual([
      { ...ana, since: '2026-11-08T09:50:00.000Z', devices: 2 },
      { ...bob, since: '2026-11-08T09:53:47.000Z', devices: 1 },
    ]);
  });

  test('nobody there: an empty list', () => {
    expect(peopleFrom({})).toEqual([]);
  });
});

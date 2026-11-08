import { routeForNotification } from '../src/notifications';

// The module's imports talk to the phone and the server: the rule does not.
jest.mock('expo-notifications', () => ({ setNotificationHandler: jest.fn() }));
jest.mock('expo-router', () => ({ router: { push: jest.fn() } }));
jest.mock('../src/supabase', () => ({ supabase: {} }));

const ID = '2511ddfb-2828-46f5-b23c-39501d862310';

describe('routeForNotification', () => {
  test('an entranceId opens that entrance', () => {
    expect(routeForNotification({ entranceId: ID })).toBe(`/entrances/${ID}`);
  });

  test('a push from FCM carries the same data (strings only)', () => {
    expect(routeForNotification({ entranceId: ID, 'google.message_id': '0:1' })).toBe(`/entrances/${ID}`);
  });

  test.each([
    ['no data', undefined],
    ['null', null],
    ['a string', 'entranceId'],
    ['no entranceId', { url: '/pins/42' }],
    ['a number', { entranceId: 42 }],
    ['not a UUID', { entranceId: '../survey/1' }],
  ])('%s opens nothing', (_name, data) => {
    expect(routeForNotification(data)).toBeNull();
  });
});

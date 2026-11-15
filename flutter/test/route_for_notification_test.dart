import 'package:field_app/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 6: routeForNotification decides where every tap goes (step 4's
/// reminders, step 5's pushes). Pure, so tested without a phone.
void main() {
  const id = '6080448f-d769-4f54-b7b2-2358af0dcdd8';

  test('an entrance id opens that entrance', () {
    expect(routeForNotification({'entranceId': id}), '/entrances/$id');
  });

  test('other keys are ignored', () {
    expect(routeForNotification({'entranceId': id, 'title': 'New entrance assigned'}), '/entrances/$id');
  });

  test('no entranceId, an empty one, or not a string: nowhere', () {
    expect(routeForNotification({}), isNull);
    expect(routeForNotification({'entranceId': ''}), isNull);
    expect(routeForNotification({'entranceId': 42}), isNull);
  });

  test('a push is data from outside the app: only a UUID becomes a route', () {
    expect(routeForNotification({'entranceId': '../sign-in'}), isNull);
    expect(routeForNotification({'entranceId': '$id/survey'}), isNull);
    expect(routeForNotification({'entranceId': 'not-an-id'}), isNull);
  });
}

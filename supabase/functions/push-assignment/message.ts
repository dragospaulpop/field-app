// The FCM HTTP v1 message for "an entrance was assigned to you". A pure
// function: no network, no secrets, so it can be tested on its own.

export type Entrance = {
  id: string;
  street: string;
  number: string;
  entrance_name: string;
};

// The Android channel both apps create at start (week 6, step 5).
export const ASSIGNMENTS_CHANNEL = 'assignments';

export function assignmentMessage(token: string, entrance: Entrance) {
  return {
    message: {
      token,
      notification: {
        title: 'New entrance assigned',
        body: `${entrance.street} ${entrance.number}, ${entrance.entrance_name}`,
      },
      // data values must be strings; the app routes a tap with entranceId.
      data: { entranceId: entrance.id },
      android: {
        priority: 'high',
        notification: { channel_id: ASSIGNMENTS_CHANNEL },
      },
    },
  };
}

// FCM says this address will never work again: delete its row. Only on
// FCM's own error codes (error.details[].errorCode): a 404 for a wrong
// project id, or a 400 for a bad message of ours, must not wipe the table.
type FcmError = {
  error?: { message?: string; details?: { errorCode?: string }[] };
};

export function isDeadToken(status: number, body: unknown): boolean {
  const error = (body as FcmError)?.error;
  const codes = (error?.details ?? []).map((d) => d.errorCode);
  if (codes.includes('UNREGISTERED')) return true; // HTTP 404: the app was uninstalled, or the token expired
  // HTTP 400: only when FCM says the token itself is malformed
  return status === 400 && codes.includes('INVALID_ARGUMENT') &&
    /registration token/i.test(error?.message ?? '');
}

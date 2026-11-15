import { skipToken, useQuery } from '@tanstack/react-query';
import { Pressable, Text, View } from 'react-native';
import { currentUser } from '../auth';
import type { Entrance } from '../contract/contract';
import { useQueue } from '../photoQueue';
import { retryFailed, useOutbox } from '../store';
import { myPinsKey, pushSurveys } from '../sync';

/** The banner's sync line: what the cloud has, what waits to be sent. */
export function SyncBar() {
  const uid = currentUser()?.id ?? '';
  // No queryFn: the pull fills this cache entry (setQueryData in sync.ts).
  const box = useOutbox();
  const queue = useQueue(); // photos not uploaded yet
  const cloud = useQuery<Entrance[]>({ queryKey: myPinsKey(uid), queryFn: skipToken });

  return (
    <View className="mt-1.5 flex-row flex-wrap items-center gap-2">
      <Text className="text-xs text-muted">
        {cloud.data ? `cloud: ${cloud.data.length} pins` : 'cloud: connecting…'}
      </Text>
      {/* A phone cannot make pins (no insert grant): the office assigns them, in SQL (step 1). */}
      {cloud.data?.length === 0 && (
        <Text className="text-xs text-muted">no pins yet: ask the office to assign some</Text>
      )}
      <Text className="text-xs text-muted">
        {box.pending} to send · {box.failed} refused · {box.lost} ignored
      </Text>
      <Pressable accessibilityRole="button" onPress={() => pushSurveys(uid)}>
        <Text className="text-xs font-semibold text-primary">Sync now</Text>
      </Pressable>
      {box.failed > 0 && (
        <Pressable accessibilityRole="button" onPress={() => retryFailed().then(() => pushSurveys(uid))}>
          <Text className="text-xs font-semibold text-primary">Retry all</Text>
        </Pressable>
      )}
      <Text className="text-xs text-muted">
        photos: {queue.filter((q) => q.state !== 'failed').length} waiting ·{' '}
        {queue.filter((q) => q.state === 'failed').length} failed
      </Text>
      {box.lastError && <Text className="text-xs text-error">last refusal: {box.lastError}</Text>}
    </View>
  );
}

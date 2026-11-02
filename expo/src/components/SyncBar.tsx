import { skipToken, useQuery } from '@tanstack/react-query';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { currentUser } from '../auth';
import type { Entrance } from '../contract/contract';
import { useOutbox } from '../store';
import { myPinsKey, pushSurveys } from '../sync';
import { useColors } from '../theme';

/** The banner's sync line: what the cloud has, what waits to be sent. */
export function SyncBar() {
  const colors = useColors();
  const uid = currentUser()?.id ?? '';
  // No queryFn: the pull fills this cache entry (setQueryData in sync.ts).
  const box = useOutbox();
  const cloud = useQuery<Entrance[]>({ queryKey: myPinsKey(uid), queryFn: skipToken });

  return (
    <View style={styles.row}>
      <Text style={{ color: colors.muted, fontSize: 12 }}>
        {cloud.data ? `cloud: ${cloud.data.length} pins` : 'cloud: connecting…'}
      </Text>
      {/* A phone cannot make pins (no insert grant): the office assigns them, in SQL (step 1). */}
      {cloud.data?.length === 0 && (
        <Text style={{ color: colors.muted, fontSize: 12 }}>no pins yet: ask the office to assign some</Text>
      )}
      <Text style={{ color: colors.muted, fontSize: 12 }}>
        {box.pending} to send · {box.failed} refused
      </Text>
      <Pressable accessibilityRole="button" onPress={() => pushSurveys(uid)}>
        <Text style={[styles.link, { color: colors.primary }]}>Sync now</Text>
      </Pressable>
      {box.lastError && <Text style={styles.error}>last refusal: {box.lastError}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: 8, marginTop: 6 },
  link: { fontSize: 12, fontWeight: '600' },
  error: { color: '#dc2626', fontSize: 12 },
});

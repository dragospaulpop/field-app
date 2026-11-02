import { StyleSheet, Text, View } from 'react-native';
import type { SyncState } from '../contract/contract';

// The contract's three sync states, per entrance (step 3).
const look: Record<SyncState, { label: string; color: string }> = {
  pending: { label: 'Waiting to send', color: '#d97706' },
  synced: { label: 'Synced ✓', color: '#16a34a' },
  failed: { label: 'Refused', color: '#dc2626' },
};

export function SyncChip({ state }: { state: SyncState }) {
  return (
    <View style={[styles.chip, { borderColor: look[state].color }]}>
      <Text style={[styles.text, { color: look[state].color }]}>{look[state].label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  chip: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 999, borderWidth: 1.5 },
  text: { fontSize: 13, fontWeight: '700' },
});

import { Text, View } from 'react-native';
import type { SyncState } from '../contract/contract';

// The contract's three sync states, per entrance. Step 2: each has an icon,
// a word and a color pair from the theme: color is never the only signal.
const look: Record<SyncState, { label: string; icon: string; box: string; text: string }> = {
  pending: { label: 'Waiting to send', icon: '⏳', box: 'bg-pending-bg border-pending', text: 'text-pending' },
  synced: { label: 'Synced', icon: '✓', box: 'bg-synced-bg border-synced', text: 'text-synced' },
  failed: { label: 'Refused', icon: '✕', box: 'bg-failed-bg border-failed', text: 'text-failed' },
};

export function SyncChip({ state }: { state: SyncState }) {
  const l = look[state];
  return (
    <View accessibilityLabel={l.label} className={`flex-row items-center gap-1 rounded-full border px-2.5 py-0.5 ${l.box}`}>
      <Text className={`text-[13px] font-bold ${l.text}`}>{l.icon}</Text>
      <Text className={`text-[13px] font-bold ${l.text}`}>{l.label}</Text>
    </View>
  );
}

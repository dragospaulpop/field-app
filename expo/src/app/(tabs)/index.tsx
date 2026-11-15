import * as Haptics from 'expo-haptics';
import { Redirect, router } from 'expo-router';
import { useNetworkState } from 'expo-network';
import { useState } from 'react';
import { Platform, Pressable, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { EntranceMap } from '../../components/EntranceMap';
import { SyncBar } from '../../components/SyncBar';
import { currentUser } from '../../auth';
import { locate } from '../../location';
import { lastTab } from '../../session';
import { addMissedEntrance, useEntrances, useField } from '../../store';
import { safeSignOut } from '../../sync';

// Read once per launch: the tab the app was closed on (the web keeps its URL instead).
let reopen = Platform.OS === 'web' ? null : lastTab.get();

export default function MapScreen() {
  const insets = useSafeAreaInsets();
  const entrances = useEntrances();
  const done = entrances.filter((e) => e.surveyStatus !== 'not_started').length;
  const [busy, setBusy] = useState(false);
  const [signOutNote, setSignOutNote] = useState<string | null>(null);
  const network = useNetworkState();
  const recent = useField((s) => s.recent); // exercise 5
  // isInternetReachable is null until the phone has checked; then true or false.
  const online = network.isConnected !== false && network.isInternetReachable !== false;

  // The office's map is missing a building: pin it where you stand, then survey it.
  const addMissed = async () => {
    setBusy(true);
    try {
      const fix = await locate();
      if (!fix) return;
      const id = await addMissedEntrance(fix);
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      router.push(`/survey/${id}`);
    } finally {
      setBusy(false);
    }
  };
  if (reopen && reopen !== '/') {
    const to = reopen;
    reopen = null;
    return <Redirect href={to as '/route' | '/inbox'} />;
  }
  reopen = null;

  return (
    <View className="flex-1 bg-background">
      <EntranceMap />
      {/* No header on this tab: the banner keeps clear of the notch itself (a value, so a style). */}
      <View
        style={{ top: insets.top + 8 }}
        className="absolute left-4 right-4 items-center rounded-xl border border-border bg-surface p-3 dark:border-transparent"
      >
        <Text className="font-semibold text-on-surface">
          {entrances.length} entrances · {done} surveyed
        </Text>
        <Text className="text-xs text-muted">
          Recently opened: {recent.length === 0 ? 'none' : recent.map((id) => entrances.find((e) => e.id === id)?.entranceName ?? '?').join(', ')}
        </Text>
        <View className="mt-1.5 flex-row items-center gap-2">
          <View className={`rounded-full px-2.5 py-0.5 ${online ? 'bg-synced-bg' : 'bg-todo-bg'}`}>
            <Text className={`text-xs font-semibold ${online ? 'text-synced' : 'text-todo'}`}>
              {online ? `Online · ${network.type ?? '…'}` : 'Offline — saved on the phone'}
            </Text>
          </View>
          <Text className="text-xs text-muted">{currentUser()?.email}</Text>
          <Pressable accessibilityRole="button" onPress={() => safeSignOut().then(setSignOutNote)}>
            <Text className="text-xs font-semibold text-primary">Sign out</Text>
          </Pressable>
        </View>
        {signOutNote && <Text className="text-xs text-error">{signOutNote}</Text>}
        <SyncBar />
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Add a building that is not on the map, here"
        disabled={busy}
        onPress={addMissed}
        className={`absolute bottom-8 right-4 min-h-13 justify-center rounded-full bg-primary px-4.5 shadow-md dark:shadow-none ${busy ? 'opacity-60' : ''}`}
      >
        <Text className="font-bold text-on-primary">
          {busy ? 'Finding you…' : '+ Missed building'}
        </Text>
      </Pressable>
    </View>
  );
}

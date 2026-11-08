import { router, useLocalSearchParams } from 'expo-router';
import { Pressable, ScrollView, Text, View } from 'react-native';
import type { Entrance } from '../../contract/contract';
import { HereCard } from '../../components/HereCard';
import { Photos } from '../../components/Photos';
import { StatusChip } from '../../components/StatusChip';
import { SyncChip } from '../../components/SyncChip';
import { useEffect, useState } from 'react';
import { currentUser } from '../../auth';
import { mayNotify, notificationsWork, remindInOneMinute } from '../../notifications';
import { markOpened, retryFailed, useBuilding, useEntrance, useField } from '../../store';
import { tryToMovePin } from '../../supabaseRepositories';
import { pushSurveys } from '../../sync';
import { fromWire, toWire } from '../../wire';

const show = (v: number | boolean | string | null) =>
  v === null ? '—' : typeof v === 'boolean' ? (v ? 'Yes' : 'No') : String(v);

export default function EntranceScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const entrance = useEntrance(id);
  // From SQLite, not the fixtures: a building made on the phone is there too.
  const building = useBuilding(entrance?.buildingId ?? '');
  // Exercises 1 and 5: remember the visit, in SQLite and in the store.
  useEffect(() => {
    markOpened(id);
    useField.getState().openRecent(id);
  }, [id]);
  const [moved, setMoved] = useState<string | null>(null);
  const [reminder, setReminder] = useState<string | null>(null);
  if (entrance === undefined) return null; // SQLite has not answered yet
  if (!entrance) {
    return <Text className="p-4 text-on-surface">No such entrance.</Text>;
  }
  const rows: [string, number | boolean | string | null][] = [
    ['Pin confirmed', entrance.coordsConfirmed],
    ['Address checked', entrance.addressConfirmed],
    ['Stories', entrance.stories],
    ['Flats', entrance.flats],
    ['Elevators', entrance.elevators],
    ['Year built', entrance.yearBuilt],
    ['Shops on the ground floor', entrance.groundFloorCommercial],
    ['Comment', entrance.comment],
  ];
  return (
    <ScrollView
      className="bg-background"
      contentContainerClassName="items-start gap-3 p-4"
    >
      {/* Step 6: testIDs are what the tests and the Maestro flow find (Android: resource-id). */}
      <Text testID="entrance-title" className="text-2xl font-bold text-on-surface">
        {entrance.street} {entrance.number}
      </Text>
      <Text className="text-muted">{entrance.entranceName}</Text>
      <Pressable
        accessibilityRole="link"
        onPress={() => router.push(`/buildings/${entrance.buildingId}`)}
        className="min-h-11 justify-center"
      >
        <Text className="font-semibold text-primary">
          {building?.label ?? 'Building'} · every entrance ›
        </Text>
      </Pressable>
      <View className="flex-row items-center gap-2">
        <StatusChip status={entrance.surveyStatus} />
        <SyncChip state={entrance.syncState} />
      </View>
      {entrance.lastError ? <Text className="text-on-surface">{entrance.lastError}</Text> : null}
      {entrance.syncState === 'failed' && (
        <Pressable
          accessibilityRole="button"
          onPress={() => retryFailed(entrance.id).then(() => pushSurveys(currentUser()?.id ?? ''))}
          className="min-h-11 justify-center"
        >
          <Text className="font-semibold text-primary">Retry</Text>
        </Pressable>
      )}
      <Text className="text-muted">
        Office pin: {entrance.lat.toFixed(5)}, {entrance.lng.toFixed(5)}
      </Text>
      {/* Step 3's check, dev builds only: the pin's place is the office's column. */}
      {__DEV__ && (
        <Pressable
          accessibilityRole="button"
          onPress={() => tryToMovePin(entrance.id, entrance.lat + 0.0001).then(setMoved)}
          className="min-h-11 justify-center"
        >
          <Text className="font-semibold text-primary">Dev: try to move this pin</Text>
        </Pressable>
      )}
      {moved ? <Text className="text-muted">{moved}</Text> : null}
      {building?.comment ? (
        <Text className="text-on-surface">Office note: {building.comment}</Text>
      ) : null}
      <View className="gap-2 self-stretch rounded-xl border border-border bg-surface p-3">
        {rows.map(([label, value]) => (
          <View key={label} className="flex-row justify-between gap-3">
            <Text className="text-muted">{label}</Text>
            <Text className="shrink text-right font-semibold text-on-surface">{show(value)}</Text>
          </View>
        ))}
      </View>
      <Pressable
        accessibilityRole="button"
        onPress={() => router.push(`/survey/${entrance.id}`)}
        className="min-h-12 items-center justify-center self-stretch rounded-xl bg-primary active:opacity-70"
      >
        <Text className="font-bold text-on-primary">Survey</Text>
      </Pressable>
      {/* Step 4: a local notification, set by the worker; its tap comes back here. */}
      <Pressable
        testID="remind-me"
        accessibilityRole="button"
        onPress={async () => {
          if (!notificationsWork) return setReminder('Reminders are phone-only: open the app on your phone.');
          const no = await mayNotify();
          if (no) return setReminder(no);
          await remindInOneMinute(entrance.id, `${entrance.street} ${entrance.number}, ${entrance.entranceName}`);
          setReminder(`Reminder set for ${new Date(Date.now() + 60_000).toLocaleTimeString()}.`);
        }}
        className="min-h-12 items-center justify-center self-stretch rounded-xl border-2 border-primary active:opacity-70"
      >
        <Text className="font-bold text-primary">Remind me in 1 minute</Text>
      </Pressable>
      {reminder ? <Text className="text-muted">{reminder}</Text> : null}
      <HereCard />
      <Text className="text-muted">
        Opened on this phone: {entrance.openedAt ? new Date(entrance.openedAt).toLocaleString() : 'never'}
      </Text>
      <WireJson entrance={entrance} />
      <Photos entranceId={entrance.id} />
    </ScrollView>
  );
}

/** Exercise 2: the entrance as it would travel, and the proof that it comes back the same. */
function WireJson({ entrance }: { entrance: Entrance }) {
  const json = toWire(entrance);
  const same = toWire(fromWire(json)) === json;
  return (
    <Text className="font-mono text-[11px] text-muted">
      {same ? 'Round trip: same JSON ✓' : 'Round trip: DIFFERENT ✗'} · {json.length} characters, {Object.keys(JSON.parse(json)).length} keys
    </Text>
  );
}

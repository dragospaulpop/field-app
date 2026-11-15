import { router } from 'expo-router';
import { useState } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';
import { StatusChip } from '../../components/StatusChip';
import { ME, routes } from '../../contract/fixtures';
import { emptyText, filterStops, STOP_FILTERS, type StopFilter } from '../../routeFilter';
import { useEntrances } from '../../store';

const myRoute = routes.find((r) => r.workerId === ME);

export default function RouteScreen() {
  const entrances = useEntrances();
  // A tab screen stays mounted, so this survives a trip to a detail and back.
  const [filter, setFilter] = useState<StopFilter>('all');
  if (!myRoute) return null;
  const stops = filterStops(myRoute.stops, filter);
  return (
    <FlatList
      className="bg-background"
      contentContainerClassName="gap-2 p-4"
      data={stops}
      keyExtractor={(s) => s.id}
      ListHeaderComponent={
        <View className="mb-2 gap-2">
          <Text className="text-lg font-bold text-on-surface">
            {myRoute.name} · {myRoute.date}
          </Text>
          <View className="flex-row flex-wrap gap-2">
            {STOP_FILTERS.map((f) => {
              const selected = f.value === filter;
              return (
                <Pressable
                  key={f.value}
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
                  onPress={() => setFilter(f.value)}
                  className={`min-h-11 justify-center rounded-full border px-3.5 ${selected ? 'border-primary bg-primary' : 'border-border'}`}
                >
                  <Text className={`font-semibold ${selected ? 'text-on-primary' : 'text-on-surface'}`}>
                    {f.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      }
      ListEmptyComponent={<Text className="text-muted">{emptyText(filter)}</Text>}
      renderItem={({ item: stop }) => {
        const e = entrances.find((x) => x.id === stop.entranceId);
        if (!e) return null;
        return (
          <Pressable
            accessibilityRole="button"
            onPress={() => router.push(`/entrances/${e.id}`)}
            className="min-h-14 flex-row items-center gap-3 rounded-xl border border-border bg-surface p-3 active:opacity-70"
          >
            <Text className="w-6 text-center text-lg font-bold text-muted">{stop.order}</Text>
            <View className="flex-1">
              <Text className="text-base text-on-surface">
                {e.street} {e.number}
              </Text>
              <Text className="text-muted">{e.entranceName}</Text>
            </View>
            <StatusChip status={e.surveyStatus} />
          </Pressable>
        );
      }}
    />
  );
}

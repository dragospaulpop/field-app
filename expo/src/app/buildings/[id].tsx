import { router, Stack, useLocalSearchParams } from 'expo-router';
import { FlatList, Pressable, Text, View } from 'react-native';
import { StatusChip } from '../../components/StatusChip';
import { SURVEYED } from '../../contract/contract';
import { buildings } from '../../contract/fixtures';
import { useEntrances } from '../../store';

export default function BuildingScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const building = buildings.find((b) => b.id === id);
  const entrances = useEntrances().filter((e) => e.buildingId === id);
  const surveyed = entrances.filter((e) => SURVEYED.includes(e.surveyStatus)).length;
  return (
    <>
      <Stack.Screen options={{ title: building?.label ?? 'Building' }} />
      <FlatList
        className="bg-background"
        contentContainerClassName="gap-2 p-4"
        data={entrances}
        keyExtractor={(e) => e.id}
        ListHeaderComponent={
          <View className="mb-2 gap-1">
            <Text className="text-[22px] font-bold text-on-surface">{building?.label ?? 'Building'}</Text>
            {building?.comment ? (
              <Text className="text-on-surface">{building.comment}</Text>
            ) : null}
            <Text className="text-muted">
              {entrances.length} entrances · {surveyed} submitted
            </Text>
          </View>
        }
        renderItem={({ item: e }) => (
          <Pressable
            accessibilityRole="button"
            onPress={() => router.push(`/entrances/${e.id}`)}
            className="min-h-14 flex-row items-center gap-3 rounded-xl border border-border bg-surface p-3 active:opacity-70"
          >
            <View className="flex-1">
              <Text className="text-base text-on-surface">{e.entranceName}</Text>
              <Text className="text-muted">
                {e.street} {e.number}
              </Text>
            </View>
            <StatusChip status={e.surveyStatus} />
          </Pressable>
        )}
      />
    </>
  );
}

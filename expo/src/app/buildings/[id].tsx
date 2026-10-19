import { router, Stack, useLocalSearchParams } from 'expo-router';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import { StatusChip } from '../../components/StatusChip';
import { SURVEYED } from '../../contract/contract';
import { buildings } from '../../contract/fixtures';
import { useEntrances } from '../../store';
import { useColors } from '../../theme';

export default function BuildingScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const colors = useColors();
  const building = buildings.find((b) => b.id === id);
  const entrances = useEntrances().filter((e) => e.buildingId === id);
  const surveyed = entrances.filter((e) => SURVEYED.includes(e.surveyStatus)).length;
  return (
    <>
      <Stack.Screen options={{ title: building?.label ?? 'Building' }} />
      <FlatList
        style={{ backgroundColor: colors.background }}
        contentContainerStyle={styles.list}
        data={entrances}
        keyExtractor={(e) => e.id}
        ListHeaderComponent={
          <View style={styles.header}>
            <Text style={[styles.h1, { color: colors.text }]}>{building?.label ?? 'Building'}</Text>
            {building?.comment ? (
              <Text style={{ color: colors.text }}>{building.comment}</Text>
            ) : null}
            <Text style={{ color: colors.muted }}>
              {entrances.length} entrances · {surveyed} submitted
            </Text>
          </View>
        }
        renderItem={({ item: e }) => (
          <Pressable
            accessibilityRole="button"
            onPress={() => router.push(`/entrances/${e.id}`)}
            style={[styles.row, { borderColor: colors.border }]}
          >
            <View style={styles.middle}>
              <Text style={{ color: colors.text, fontSize: 16 }}>{e.entranceName}</Text>
              <Text style={{ color: colors.muted }}>
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

const styles = StyleSheet.create({
  list: { padding: 16, gap: 8 },
  header: { gap: 4, marginBottom: 8 },
  h1: { fontSize: 22, fontWeight: '700' },
  row: {
    minHeight: 56,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 12,
    borderWidth: 1,
    borderRadius: 12,
  },
  middle: { flex: 1 },
});

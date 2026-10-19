import { router } from 'expo-router';
import { useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import { StatusChip } from '../../components/StatusChip';
import { ME, routes } from '../../contract/fixtures';
import { emptyText, filterStops, STOP_FILTERS, type StopFilter } from '../../routeFilter';
import { useEntrances } from '../../store';
import { useColors } from '../../theme';

const myRoute = routes.find((r) => r.workerId === ME);

export default function RouteScreen() {
  const entrances = useEntrances();
  const colors = useColors();
  // A tab screen stays mounted, so this survives a trip to a detail and back.
  const [filter, setFilter] = useState<StopFilter>('all');
  if (!myRoute) return null;
  const stops = filterStops(myRoute.stops, filter);
  return (
    <FlatList
      style={{ backgroundColor: colors.background }}
      contentContainerStyle={styles.list}
      data={stops}
      keyExtractor={(s) => s.id}
      ListHeaderComponent={
        <View style={styles.headerBox}>
          <Text style={[styles.header, { color: colors.text }]}>
            {myRoute.name} · {myRoute.date}
          </Text>
          <View style={styles.filters}>
            {STOP_FILTERS.map((f) => {
              const selected = f.value === filter;
              return (
                <Pressable
                  key={f.value}
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
                  onPress={() => setFilter(f.value)}
                  style={[
                    styles.filter,
                    { borderColor: colors.border },
                    selected && { backgroundColor: colors.primary, borderColor: colors.primary },
                  ]}
                >
                  <Text style={{ color: selected ? colors.onPrimary : colors.text, fontWeight: '600' }}>
                    {f.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      }
      ListEmptyComponent={<Text style={{ color: colors.muted }}>{emptyText(filter)}</Text>}
      renderItem={({ item: stop }) => {
        const e = entrances.find((x) => x.id === stop.entranceId);
        if (!e) return null;
        return (
          <Pressable
            accessibilityRole="button"
            onPress={() => router.push(`/entrances/${e.id}`)}
            style={[styles.row, { borderColor: colors.border }]}
          >
            <Text style={[styles.order, { color: colors.muted }]}>{stop.order}</Text>
            <View style={styles.middle}>
              <Text style={{ color: colors.text, fontSize: 16 }}>
                {e.street} {e.number}
              </Text>
              <Text style={{ color: colors.muted }}>{e.entranceName}</Text>
            </View>
            <StatusChip status={e.surveyStatus} />
          </Pressable>
        );
      }}
    />
  );
}

const styles = StyleSheet.create({
  list: { padding: 16, gap: 8 },
  headerBox: { gap: 8, marginBottom: 8 },
  header: { fontSize: 18, fontWeight: '700' },
  filters: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  filter: {
    minHeight: 44,
    paddingHorizontal: 14,
    borderWidth: 1,
    borderRadius: 999,
    justifyContent: 'center',
  },
  row: {
    minHeight: 56,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 12,
    borderWidth: 1,
    borderRadius: 12,
  },
  order: { width: 24, fontSize: 18, fontWeight: '700', textAlign: 'center' },
  middle: { flex: 1 },
});

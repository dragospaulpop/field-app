import { Stack } from 'expo-router';
import { memo, Profiler } from 'react';
import { FlatList, Image, Text, View } from 'react-native';
import { makeRows, type PerfRow } from '../perfRows';

// Week 6, step 7: a long list to measure, never real data. 3,000 made-up survey
// rows, built in memory: nothing in SQLite, nothing synced, and nothing in the
// app links here; it opens only by its address (fieldapp://perf).
const rows = makeRows(3000);
const thumb = require('../../assets/icon.png'); // the same picture on every row

// AFTER: memo: a row whose data did not change is not rendered again.
const SurveyRow = memo(function SurveyRow({ row }: { row: PerfRow }) {
  return (
    <View className="h-16 flex-row items-center gap-3 border-b border-border px-4">
      <Image source={thumb} style={{ width: 48, height: 48, borderRadius: 8 }} />
      <View className="flex-1">
        <Text className="text-on-surface" numberOfLines={1}>
          {row.street}
        </Text>
        <Text className="text-muted" numberOfLines={1}>
          {row.entrance} · {row.stories} stories · {row.flats} flats
        </Text>
      </View>
    </View>
  );
});

const ROW = 64; // h-16: every row is 64 dp, so the list can compute where row n is

// React's Profiler: how long each render of the list took (development builds only).
const report = (id: string, phase: string, ms: number) => console.log(`[perf] ${id} ${phase}: ${ms.toFixed(0)} ms`);

export default function PerfScreen() {
  return (
    <>
      <Stack.Screen options={{ title: `${rows.length} surveys (test data)` }} />
      <Profiler id="list" onRender={report}>
        {/* AFTER: only the rows near the screen exist; the rest are made while you scroll. */}
        <FlatList
          testID="perf-list"
          className="bg-background"
          data={rows}
          keyExtractor={(row) => row.id}
          renderItem={({ item }) => <SurveyRow row={item} />}
          getItemLayout={(_, index) => ({ length: ROW, offset: ROW * index, index })}
        />
      </Profiler>
    </>
  );
}

import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { pins } from '../cloud';
import { entrances as fixtureEntrances } from '../contract/fixtures';
import { auth } from '../firebase';
import { useColors } from '../theme';

/** The banner's sync line: what the cloud has, what waits to be sent. */
export function SyncBar() {
  const colors = useColors();
  const uid = auth.currentUser?.uid ?? '';
  const [seeded, setSeeded] = useState<string | null>(null);

  // Dev only: until the office side exists (week 7), the contract's fixtures
  // become my pins. __DEV__ is false in a release build: the button disappears.
  const seed = async () => {
    setSeeded('Seeding…');
    const { created, refused } = await pins.seed(uid, fixtureEntrances);
    setSeeded(`${created} pins are yours · ${refused} already someone else's`);
  };

  return (
    <View style={styles.row}>
      {__DEV__ && (
        <Pressable accessibilityRole="button" onPress={seed}>
          <Text style={[styles.link, { color: colors.primary }]}>Seed my pins</Text>
        </Pressable>
      )}
      {seeded && <Text style={{ color: colors.muted, fontSize: 12 }}>{seeded}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: 8, marginTop: 6 },
  link: { fontSize: 12, fontWeight: '600' },
});

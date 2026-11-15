import { useForm } from '@tanstack/react-form';
import * as Haptics from 'expo-haptics';
import Storage from 'expo-sqlite/kv-store';
import { router, useLocalSearchParams } from 'expo-router';
import { type ReactNode, useEffect, useMemo } from 'react';
import { AppState, Pressable, Switch, Text, TextInput, View } from 'react-native';
import { KeyboardAwareScrollView } from 'react-native-keyboard-controller';
import { type Entrance, EntranceSurvey } from '../../contract/contract';
import { locate } from '../../location';
import { currentUser } from '../../auth';
import { submitSurvey, useEntrance } from '../../store';
import { pushSurveys } from '../../sync';

// An empty number box is NaN, which the schema refuses ("expected number").
const toNumber = (text: string) => (text.trim() === '' ? Number.NaN : Number(text));
const toNullable = (text: string) => (text.trim() === '' ? null : Number(text));
const fromNumber = (n: number | null) =>
  n === null || Number.isNaN(n) ? '' : String(n);

export default function SurveyScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const entrance = useEntrance(id);
  // The row comes from SQLite just after the first render: build the form
  // only once it is here, so the form's default values are the entrance's.
  if (!entrance) return null;
  return <SurveyForm id={id} entrance={entrance} />;
}

function SurveyForm({ id, entrance }: { id: string; entrance: Entrance }) {
  const draftKey = `field.draft.${id}`;
  const draft = useMemo(() => {
    const saved = Storage.getItemSync(draftKey);
    return saved ? JSON.parse(saved) : null;
  }, [draftKey]);

  const form = useForm({
    // Exercise 4: a draft saved when the app went to the background wins.
    defaultValues: draft ?? {
      coordsConfirmed: entrance?.coordsConfirmed ?? false,
      correctedLat: entrance?.correctedLat ?? null,
      correctedLng: entrance?.correctedLng ?? null,
      street: entrance?.street ?? '',
      number: entrance?.number ?? '',
      entranceName: entrance?.entranceName ?? '',
      addressConfirmed: entrance?.addressConfirmed ?? false,
      stories: entrance?.stories ?? Number.NaN,
      flats: entrance?.flats ?? Number.NaN,
      elevators: entrance?.elevators ?? Number.NaN,
      yearBuilt: entrance?.yearBuilt ?? Number.NaN,
      groundFloorCommercial: entrance?.groundFloorCommercial ?? false,
      comment: entrance?.comment ?? null,
    },
    // The contract's own schema validates the whole form on every change.
    validators: { onChange: EntranceSurvey },
    onSubmit: async ({ value }) => {
      await submitSurvey(id, EntranceSurvey.parse(value));
      pushSurveys(currentUser()?.id ?? ''); // and send it now, if the network is there
      Storage.removeItemSync(draftKey); // submitted: the draft is done
      // Saved: say it with the hand as well as the eyes (a no-op on the web).
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      router.back();
    },
  });

  // Exercise 4: the phone may kill an app in the background without warning,
  // so write what was typed when the app leaves the screen.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'background') Storage.setItemSync(draftKey, JSON.stringify(form.state.values));
    });
    return () => sub.remove();
  }, [form, draftKey]);

  // Step 2: one className for every text box (the theme's colors, light and dark).
  const box = 'rounded-[10px] border border-border px-3 text-base text-on-surface';
  const input = `min-h-12 ${box}`;

  return (
    // Edge to edge, Android no longer shrinks the window for the keyboard:
    // this ScrollView scrolls the focused field above it, on both platforms.
    <KeyboardAwareScrollView
      // The caret stays 80 dp above the keyboard: enough to show the whole comment box.
      bottomOffset={80}
      keyboardShouldPersistTaps="handled"
      className="flex-1 bg-background"
    >
      <View className="gap-3.5 p-4">
        <form.Field name="coordsConfirmed">
          {(field) => (
            <Row label="The pin is at the door" errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
              <Switch value={field.state.value} onValueChange={field.handleChange} />
            </Row>
          )}
        </form.Field>
        <form.Subscribe selector={(s) => s.values.coordsConfirmed}>
          {(confirmed) =>
            confirmed ? null : (
              <View className="gap-3.5">
                <form.Field name="correctedLat">
                  {(field) => (
                    <Labeled label="Corrected latitude" errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
                      <TextInput className={input} keyboardType="decimal-pad" value={fromNumber(field.state.value)} onChangeText={(t) => field.handleChange(toNullable(t))} onBlur={field.handleBlur} />
                    </Labeled>
                  )}
                </form.Field>
                <form.Field name="correctedLng">
                  {(field) => (
                    <Labeled label="Corrected longitude" errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
                      <TextInput className={input} keyboardType="decimal-pad" value={fromNumber(field.state.value)} onChangeText={(t) => field.handleChange(toNullable(t))} onBlur={field.handleBlur} />
                    </Labeled>
                  )}
                </form.Field>
                <Pressable
                  accessibilityRole="button"
                  onPress={async () => {
                    const fix = await locate();
                    if (!fix) return;
                    // Five decimals is about a metre: more would be false precision.
                    form.setFieldValue('correctedLat', Number(fix.lat.toFixed(5)));
                    form.setFieldValue('correctedLng', Number(fix.lng.toFixed(5)));
                  }}
                  className="min-h-12 items-center justify-center rounded-xl border-2 border-primary"
                >
                  <Text className="font-bold text-primary">
                    Use my position
                  </Text>
                </Pressable>
              </View>
            )
          }
        </form.Subscribe>

        {(['street', 'number', 'entranceName'] as const).map((name) => (
          <form.Field key={name} name={name}>
            {(field) => (
              <Labeled label={{ street: 'Street', number: 'Number', entranceName: 'Entrance' }[name]} errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
                <TextInput className={input} value={field.state.value} onChangeText={field.handleChange} onBlur={field.handleBlur} />
              </Labeled>
            )}
          </form.Field>
        ))}
        <form.Field name="addressConfirmed">
          {(field) => (
            <Row label="I checked the address" errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
              <Switch value={field.state.value} onValueChange={field.handleChange} />
            </Row>
          )}
        </form.Field>

        {(
          [
            ['stories', 'Stories'],
            ['flats', 'Flats'],
            ['elevators', 'Elevators'],
            ['yearBuilt', 'Year built'],
          ] as const
        ).map(([name, label]) => (
          <form.Field key={name} name={name}>
            {(field) => (
              <Labeled label={label} errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
                <TextInput className={input} keyboardType="number-pad" value={fromNumber(field.state.value)} onChangeText={(t) => field.handleChange(toNumber(t))} onBlur={field.handleBlur} />
              </Labeled>
            )}
          </form.Field>
        ))}
        <form.Field name="groundFloorCommercial">
          {(field) => (
            <Row label="Shops on the ground floor" errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
              <Switch value={field.state.value} onValueChange={field.handleChange} />
            </Row>
          )}
        </form.Field>
        <form.Field name="comment">
          {(field) => (
            <Labeled label="Comment" errors={field.state.meta.errors} touched={field.state.meta.isTouched}>
              <TextInput className={`min-h-24 pt-3 ${box}`} style={{ textAlignVertical: 'top' }} multiline value={field.state.value ?? ''} onChangeText={(t) => field.handleChange(t === '' ? null : t)} onBlur={field.handleBlur} />
            </Labeled>
          )}
        </form.Field>

        <form.Subscribe selector={(s) => [s.canSubmit, s.isSubmitting] as const}>
          {([canSubmit, isSubmitting]) => (
            <Pressable
              accessibilityRole="button"
              accessibilityState={{ disabled: !canSubmit }}
              disabled={!canSubmit || isSubmitting}
              onPress={() => form.handleSubmit()}
              className={`mt-2 min-h-13 items-center justify-center rounded-xl ${canSubmit ? 'bg-primary' : 'bg-border'}`}
            >
              <Text className={`font-bold ${canSubmit ? 'text-on-primary' : 'text-muted'}`}>Submit survey</Text>
            </Pressable>
          )}
        </form.Subscribe>
      </View>
    </KeyboardAwareScrollView>
  );
}

type FieldProps = {
  label: string;
  errors: unknown[];
  touched: boolean;
  children: ReactNode;
};

/** Errors show once the user has touched the field (or pressed Submit). */
function Errors({ errors, touched }: Omit<FieldProps, 'label' | 'children'>) {
  if (!touched || errors.length === 0) return null;
  const text = errors
    .map((e) => (typeof e === 'object' && e && 'message' in e ? String(e.message) : String(e)))
    .join(' · ');
  return <Text className="text-error">{text}</Text>;
}

function Labeled({ label, children, ...rest }: FieldProps) {
  return (
    <View className="gap-1">
      <Text className="text-muted">{label}</Text>
      {children}
      <Errors {...rest} />
    </View>
  );
}

function Row({ label, children, ...rest }: FieldProps) {
  return (
    <View className="gap-1">
      <View className="min-h-12 flex-row items-center">
        <Text className="flex-1 text-on-surface">{label}</Text>
        {children}
      </View>
      <Errors {...rest} />
    </View>
  );
}

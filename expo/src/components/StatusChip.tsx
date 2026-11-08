import { Text, View } from 'react-native';
import type { SurveyStatus } from '../contract/contract';
import { statusClass, statusLabel } from '../theme';

export function StatusChip({ status }: { status: SurveyStatus }) {
  return (
    <View className={`rounded-full px-2.5 py-1 ${statusClass[status].box}`}>
      <Text className={`text-[13px] font-semibold ${statusClass[status].text}`}>{statusLabel[status]}</Text>
    </View>
  );
}

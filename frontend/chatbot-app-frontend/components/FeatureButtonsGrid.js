import React from 'react';
import { View, StyleSheet } from 'react-native';
import FeatureButton from './FeatureButton';

import { MaterialIcons, Ionicons, FontAwesome5 } from '@expo/vector-icons';

export default function FeatureButtonsGrid({ onSelect }) {
  return (
    <View style={styles.container}>
      <FeatureButton
        icon={<MaterialIcons name="format-list-bulleted" size={20} color="#555" />}
        label="Payments & transfers"
        onPress={() => onSelect('payments')}
      />
      <FeatureButton
        icon={<MaterialIcons name="bar-chart" size={20} color="#555" />}
        label="Spending insights"
        onPress={() => onSelect('spending')}
      />
      <FeatureButton
        icon={<Ionicons name="wallet-outline" size={20} color="#555" />}
        label="Personal finance & accounts"
        onPress={() => onSelect('finance')}
      />
      <FeatureButton
        icon={<FontAwesome5 name="piggy-bank" size={20} color="#555" />}
        label="Savings & investments"
        onPress={() => onSelect('savings')}
      />
      <FeatureButton
        icon={<Ionicons name="bulb-outline" size={20} color="#555" />}
        label="Support & service"
        onPress={() => onSelect('support')}
      />
      <FeatureButton
        icon={<MaterialIcons name="search" size={20} color="#555" />}
        label="Last electricity bill payment"
        onPress={() => onSelect('bill')}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexWrap: 'wrap',
    flexDirection: 'row',
    justifyContent: 'flex-start',
    marginBottom: 24,
  },
});

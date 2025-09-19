import React from 'react';
import { View, StyleSheet, Image} from 'react-native';
import FeatureButton from './FeatureButton';


// Import icons as images from assets
const icons = {
  payments: require('../assets/icons/Transfers.svg'),
  spending: require('../assets/icons/Spends.svg'),
  finance: require('../assets/icons/Finance.svg'),
  savings: require('../assets/icons/Savings.svg'),
  support: require('../assets/icons/Support.svg'),
  bill: require('../assets/icons/Search.svg'),
};

export default function FeatureButtonsGrid({ onSelect }) {
  return (
    <View style={styles.container}>
      <FeatureButton
        icon={<Image source={icons.payments} style={styles.icon} />}
        label="Payments & transfers"
        onPress={() => onSelect('payments')}
      />
      <FeatureButton
        icon={<Image source={icons.spending} style={styles.icon} />}
        label="Spending insights"
        onPress={() => onSelect('spending')}
      />
      <FeatureButton
        icon={<Image source={icons.finance} style={styles.icon} />}
        label="Personal finance & accounts"
        onPress={() => onSelect('finance')}
      />
      <FeatureButton
        icon={<Image source={icons.savings} style={styles.icon} />}
        label="Savings & investments"
        onPress={() => onSelect('savings')}
      />
      <FeatureButton
        icon={<Image source={icons.support} style={styles.icon} />}
        label="Support & service"
        onPress={() => onSelect('support')}
      />
      <FeatureButton
        icon={<Image source={icons.bill} style={styles.icon} />}
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
  icon: {
    width: 20,
    height: 20,
    resizeMode: 'contain',
  },
});

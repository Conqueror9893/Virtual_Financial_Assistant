import React from 'react';
import { TouchableOpacity, Text, StyleSheet, View } from 'react-native';

export default function FeatureButton({ icon, label, onPress }) {
  return (
    <TouchableOpacity onPress={onPress} style={styles.button}>
      <View style={styles.iconWrapper}>{icon}</View>
      <Text style={styles.label}>{label}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#f7f7f7',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 25,
    margin: 6,
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconWrapper: {
    marginRight: 8,
  },
  label: {
    fontSize: 15,
    color: '#000',
  },
});

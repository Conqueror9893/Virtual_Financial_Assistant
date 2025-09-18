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
    backgroundColor: '#f5f5f6',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 30,
    margin: 8,
    flexDirection: 'row',
    alignItems: 'center',
    minWidth: 150,
    justifyContent: 'center',
  },
  iconWrapper: {
    marginRight: 8,
  },
  label: {
    fontSize: 15,
    color: '#000',
  },
});

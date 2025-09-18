import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

export default function Header({ onBack }) {
  return (
    <View style={styles.container}>
      <TouchableOpacity onPress={onBack} style={styles.backButton}>
        <Ionicons name="arrow-back" size={24} color="#000" />
      </TouchableOpacity>
      <Text style={styles.title}>Speaking to Ai Bot</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingTop: 40,
    paddingBottom: 20,
    paddingHorizontal: 16,
    backgroundColor: 'transparent',
  },
  backButton: {
    marginRight: 12,
    padding: 8,
    backgroundColor: 'rgba(255,255,255,0.4)',
    borderRadius: 20,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    color: '#000',
  },
});

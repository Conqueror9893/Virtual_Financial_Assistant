import React from 'react';
import { View, Text, Image, StyleSheet } from 'react-native';

export default function BotGreeting() {
  return (
    <View style={styles.container}>
      <Image source={require('../assets/avatar.png')} style={styles.avatar} />
      <Text style={styles.headerText}>Hi, I’m Appzia</Text>
      <Text style={styles.subText}>
        I can help you check your{' '}
        <Text style={styles.highlight}>accounts, spending, or transfers</Text>
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    marginBottom: 24,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    marginBottom: 12,
  },
  headerText: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 8,
    color: '#000',
  },
  subText: {
    fontSize: 16,
    color: '#444',
    textAlign: 'center',
    maxWidth: '80%',
  },
  highlight: {
    color: '#f47427', // orange tone
    fontWeight: '600',
  },
});

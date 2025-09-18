import React, { useState } from 'react';
import { SafeAreaView, ScrollView, StyleSheet, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';

import Header from '../components/Header';
import BotGreeting from '../components/BotGreeting';
import FeatureButtonsGrid from '../components/FeatureButtonsGrid';
import ChatInputBar from '../components/ChatInputBar';

export default function ChatbotLandingPage({ navigation }) {
  const [inputText, setInputText] = useState('');

  function handleBack() {
    navigation.goBack();
  }

  function handleFeatureSelect(feature) {
    // Placeholder: handle feature button press
    console.log('Selected feature:', feature);
  }

  function handleMicPress() {
    // Placeholder: handle voice input action
    console.log('Mic pressed');
  }

  return (
    <View style={styles.container}>
      <LinearGradient
        colors={['#fde7d5', '#ffffff']}
        style={styles.gradient}
      />
      <SafeAreaView style={styles.safeArea}>
        <ScrollView contentContainerStyle={styles.content}>
          <Header onBack={handleBack} />
          <BotGreeting />
          <FeatureButtonsGrid onSelect={handleFeatureSelect} />
        </ScrollView>
        <ChatInputBar
          value={inputText}
          onChangeText={setInputText}
          onMicPress={handleMicPress}
        />
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  gradient: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    height: '100%',
  },
  safeArea: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  content: {
    paddingVertical: 20,
    paddingHorizontal: 16,
  },
});

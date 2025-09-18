import React, { useState } from 'react';
import { SafeAreaView, ScrollView, StyleSheet } from 'react-native';

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
    <SafeAreaView style={styles.container}>
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
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fcbd86', // Gradient is simplified here
  },
  content: {
    paddingVertical: 20,
    paddingHorizontal: 16,
  },
});

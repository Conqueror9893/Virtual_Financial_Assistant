import React from 'react';
import { View, TextInput, StyleSheet, TouchableOpacity, Text } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';

export default function ChatInputBar({ value, onChangeText, onMicPress }) {
  return (
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        placeholder="Chat with Appzia"
        value={value}
        onChangeText={onChangeText}
        underlineColorAndroid="transparent"
      />
      <TouchableOpacity style={styles.micButton} onPress={onMicPress}>
        <MaterialIcons name="keyboard-voice" size={28} color="#f47427" />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginHorizontal: 16,
    marginBottom: 40,
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderRadius: 26,
    alignItems: 'center',
    paddingHorizontal: 16,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 5,
    elevation: 4,
    height: 50,
  },
  input: {
    flex: 1,
    fontSize: 16,
    paddingVertical: 10,
    color: '#000',
  },
  micButton: {
    marginLeft: 10,
  },
});

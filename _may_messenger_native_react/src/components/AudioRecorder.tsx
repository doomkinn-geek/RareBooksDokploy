import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { IconButton, Text } from 'react-native-paper';

interface AudioRecorderProps {
  onSend: (audioPath: string) => void;
  onCancel: () => void;
}

const AudioRecorder: React.FC<AudioRecorderProps> = ({ onSend, onCancel }) => {
  const [recording, setRecording] = useState(false);
  const [duration, setDuration] = useState(0);

  // Simplified implementation - actual recording would use react-native-audio-recorder-player
  const handleToggleRecording = () => {
    if (!recording) {
      setRecording(true);
      // Start recording logic here
    } else {
      setRecording(false);
      // Stop and save recording
      onSend('temp-audio-path');
    }
  };

  return (
    <View style={styles.container}>
      <IconButton
        icon="close"
        size={24}
        onPress={onCancel}
      />
      <View style={styles.center}>
        <Text>{recording ? `Запись... ${duration}s` : 'Нажмите для записи'}</Text>
      </View>
      <IconButton
        icon={recording ? 'stop' : 'microphone'}
        size={32}
        onPress={handleToggleRecording}
        iconColor={recording ? '#F44336' : '#2196F3'}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 8,
    backgroundColor: 'white',
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  center: {
    flex: 1,
    alignItems: 'center',
  },
});

export default AudioRecorder;


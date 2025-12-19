import React, { useState, useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { IconButton, Text, Surface } from 'react-native-paper';
import AudioRecorderPlayer from 'react-native-audio-recorder-player';
import { PermissionsAndroid, Platform } from 'react-native';

interface AudioRecorderFullProps {
  onSend: (audioPath: string) => void;
  onCancel: () => void;
}

// @ts-ignore - react-native-audio-recorder-player typing issue
const audioRecorderPlayer = new AudioRecorderPlayer();

const AudioRecorderFull: React.FC<AudioRecorderFullProps> = ({ onSend, onCancel }) => {
  const [recording, setRecording] = useState(false);
  const [duration, setDuration] = useState(0);
  const [audioPath, setAudioPath] = useState<string | null>(null);

  useEffect(() => {
    requestPermissions();
    return () => {
      audioRecorderPlayer.stopRecorder();
    };
  }, []);

  const requestPermissions = async () => {
    if (Platform.OS === 'android') {
      try {
        const grants = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
          PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        ]);

        if (
          grants['android.permission.WRITE_EXTERNAL_STORAGE'] === PermissionsAndroid.RESULTS.GRANTED &&
          grants['android.permission.READ_EXTERNAL_STORAGE'] === PermissionsAndroid.RESULTS.GRANTED &&
          grants['android.permission.RECORD_AUDIO'] === PermissionsAndroid.RESULTS.GRANTED
        ) {
          console.log('Permissions granted');
        } else {
          console.log('All required permissions not granted');
        }
      } catch (err) {
        console.warn(err);
      }
    }
  };

  const startRecording = async () => {
    try {
      const path = Platform.select({
        ios: 'audio.m4a',
        android: `${audioRecorderPlayer.path()}/audio_${Date.now()}.m4a`,
      });

      await audioRecorderPlayer.startRecorder(path);
      setRecording(true);

      audioRecorderPlayer.addRecordBackListener((e: any) => {
        setDuration(Math.floor(e.currentPosition / 1000));
      });
    } catch (error) {
      console.error('Failed to start recording:', error);
    }
  };

  const stopRecording = async () => {
    try {
      const result = await audioRecorderPlayer.stopRecorder();
      audioRecorderPlayer.removeRecordBackListener();
      setRecording(false);
      setAudioPath(result);
      console.log('Recording stopped:', result);
    } catch (error) {
      console.error('Failed to stop recording:', error);
    }
  };

  const handleToggleRecording = async () => {
    if (recording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  };

  const handleSend = () => {
    if (audioPath) {
      onSend(audioPath);
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <Surface style={styles.container} elevation={4}>
      <IconButton
        icon="close"
        size={24}
        onPress={onCancel}
      />
      <View style={styles.center}>
        <Text variant="titleMedium" style={styles.timeText}>
          {formatTime(duration)}
        </Text>
        <Text variant="bodySmall" style={styles.statusText}>
          {recording ? '🔴 Запись...' : audioPath ? '✅ Готово' : 'Нажмите для записи'}
        </Text>
      </View>
      {!audioPath ? (
        <IconButton
          icon={recording ? 'stop' : 'microphone'}
          size={32}
          onPress={handleToggleRecording}
          iconColor={recording ? '#F44336' : '#2196F3'}
        />
      ) : (
        <IconButton
          icon="send"
          size={32}
          onPress={handleSend}
          iconColor="#4CAF50"
        />
      )}
    </Surface>
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
  timeText: {
    fontWeight: 'bold',
    color: '#2196F3',
  },
  statusText: {
    marginTop: 4,
    color: '#757575',
  },
});

export default AudioRecorderFull;


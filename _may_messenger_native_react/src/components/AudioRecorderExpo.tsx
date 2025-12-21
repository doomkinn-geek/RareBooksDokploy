import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Text, TouchableOpacity, Animated, Platform } from 'react-native';
import { Audio } from 'expo-av';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';

interface AudioRecorderExpoProps {
  onSend: (audioUri: string) => void;
  onCancel: () => void;
}

const AudioRecorderExpo: React.FC<AudioRecorderExpoProps> = ({ onSend, onCancel }) => {
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [duration, setDuration] = useState(0);
  const [isRecording, setIsRecording] = useState(false);
  const slideAnim = useState(new Animated.Value(0))[0];

  useEffect(() => {
    startRecording();
    
    Animated.spring(slideAnim, {
      toValue: 1,
      useNativeDriver: true,
    }).start();

    return () => {
      if (recording) {
        recording.stopAndUnloadAsync();
      }
    };
  }, []);

  const startRecording = async () => {
    try {
      // Request permission
      const { status } = await Audio.requestPermissionsAsync();
      if (status !== 'granted') {
        console.log('Permission denied');
        onCancel();
        return;
      }

      // Set audio mode
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      // Configure recording
      const recordingOptions: Audio.RecordingOptions = {
        android: {
          extension: '.m4a',
          outputFormat: Audio.AndroidOutputFormat.MPEG_4,
          audioEncoder: Audio.AndroidAudioEncoder.AAC,
          sampleRate: 44100,
          numberOfChannels: 1,
          bitRate: 128000,
        },
        ios: {
          extension: '.m4a',
          outputFormat: Audio.IOSOutputFormat.MPEG4AAC,
          audioQuality: Audio.IOSAudioQuality.HIGH,
          sampleRate: 44100,
          numberOfChannels: 1,
          bitRate: 128000,
          linearPCMBitDepth: 16,
          linearPCMIsBigEndian: false,
          linearPCMIsFloat: false,
        },
        web: {
          mimeType: 'audio/webm',
          bitsPerSecond: 128000,
        },
      };

      const { recording: newRecording } = await Audio.Recording.createAsync(
        recordingOptions
      );
      
      setRecording(newRecording);
      setIsRecording(true);

      // Update duration every second
      const interval = setInterval(() => {
        setDuration((prev) => prev + 1);
      }, 1000);

      // Store interval for cleanup
      (newRecording as any)._interval = interval;
    } catch (error) {
      console.error('Failed to start recording:', error);
      onCancel();
    }
  };

  const stopRecording = async () => {
    if (!recording) return;

    try {
      setIsRecording(false);
      
      // Clear interval
      if ((recording as any)._interval) {
        clearInterval((recording as any)._interval);
      }

      await recording.stopAndUnloadAsync();
      const uri = recording.getURI();
      
      if (uri) {
        onSend(uri);
      } else {
        onCancel();
      }
    } catch (error) {
      console.error('Failed to stop recording:', error);
      onCancel();
    }
  };

  const cancelRecording = async () => {
    if (recording) {
      try {
        // Clear interval
        if ((recording as any)._interval) {
          clearInterval((recording as any)._interval);
        }
        
        await recording.stopAndUnloadAsync();
      } catch (error) {
        console.error('Failed to cancel recording:', error);
      }
    }
    onCancel();
  };

  const formatDuration = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <Animated.View 
      style={[
        styles.container,
        {
          transform: [{
            translateX: slideAnim.interpolate({
              inputRange: [0, 1],
              outputRange: [-300, 0],
            }),
          }],
        },
      ]}
    >
      <TouchableOpacity onPress={cancelRecording} style={styles.cancelButton}>
        <Icon name="close" size={24} color="#F44336" />
      </TouchableOpacity>

      <View style={styles.recordingInfo}>
        <Icon name="microphone" size={24} color="#F44336" />
        <Text style={styles.durationText}>{formatDuration(duration)}</Text>
        <View style={styles.pulseContainer}>
          <View style={[styles.pulse, isRecording && styles.pulseActive]} />
        </View>
      </View>

      <TouchableOpacity onPress={stopRecording} style={styles.sendButton}>
        <Icon name="send" size={24} color="#2196F3" />
      </TouchableOpacity>
    </Animated.View>
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
  cancelButton: {
    padding: 8,
    marginRight: 12,
  },
  recordingInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  durationText: {
    fontSize: 16,
    fontWeight: 'bold',
    marginLeft: 12,
    color: '#333',
  },
  pulseContainer: {
    marginLeft: 12,
    width: 12,
    height: 12,
  },
  pulse: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#F44336',
  },
  pulseActive: {
    opacity: 0.6,
  },
  sendButton: {
    padding: 8,
    marginLeft: 12,
  },
});

export default AudioRecorderExpo;


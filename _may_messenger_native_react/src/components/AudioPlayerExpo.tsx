import React, { useState, useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { IconButton, Text, ProgressBar } from 'react-native-paper';
import { Audio, AVPlaybackStatus } from 'expo-av';

interface AudioPlayerExpoProps {
  audioUrl: string;
  duration?: number;
}

const AudioPlayerExpo: React.FC<AudioPlayerExpoProps> = ({ audioUrl, duration = 0 }) => {
  const [sound, setSound] = useState<Audio.Sound | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [totalDuration, setTotalDuration] = useState(duration * 1000); // Convert to ms

  useEffect(() => {
    return () => {
      if (sound) {
        sound.unloadAsync();
      }
    };
  }, [sound]);

  const loadAndPlaySound = async () => {
    try {
      const { sound: newSound } = await Audio.Sound.createAsync(
        { uri: audioUrl },
        { shouldPlay: true },
        onPlaybackStatusUpdate
      );
      setSound(newSound);
      setIsPlaying(true);
    } catch (error) {
      console.error('Error loading sound:', error);
    }
  };

  const onPlaybackStatusUpdate = (status: AVPlaybackStatus) => {
    if (status.isLoaded) {
      setCurrentPosition(status.positionMillis);
      setTotalDuration(status.durationMillis || 0);
      setIsPlaying(status.isPlaying);

      if (status.didJustFinish) {
        setIsPlaying(false);
        setCurrentPosition(0);
      }
    }
  };

  const handlePlayPause = async () => {
    try {
      if (!sound) {
        await loadAndPlaySound();
      } else {
        if (isPlaying) {
          await sound.pauseAsync();
        } else {
          await sound.playAsync();
        }
      }
    } catch (error) {
      console.error('Error playing/pausing sound:', error);
    }
  };

  const formatTime = (milliseconds: number) => {
    const seconds = Math.floor(milliseconds / 1000);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const progress = totalDuration > 0 ? currentPosition / totalDuration : 0;

  return (
    <View style={styles.container}>
      <IconButton
        icon={isPlaying ? 'pause' : 'play'}
        size={24}
        onPress={handlePlayPause}
        iconColor="#2196F3"
      />
      <View style={styles.progressContainer}>
        <ProgressBar progress={progress} color="#2196F3" style={styles.progressBar} />
        <Text style={styles.timeText}>
          {formatTime(currentPosition)} / {formatTime(totalDuration)}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 8,
    minWidth: 200,
  },
  progressContainer: {
    flex: 1,
    marginLeft: 8,
  },
  progressBar: {
    height: 4,
    borderRadius: 2,
  },
  timeText: {
    fontSize: 12,
    color: '#757575',
    marginTop: 4,
  },
});

export default AudioPlayerExpo;


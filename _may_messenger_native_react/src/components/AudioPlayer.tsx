import React, { useState, useEffect } from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { IconButton, Text, ProgressBar } from 'react-native-paper';
import AudioRecorderPlayer from 'react-native-audio-recorder-player';

interface AudioPlayerProps {
  audioUrl: string;
  duration?: number;
}

// @ts-ignore - react-native-audio-recorder-player typing issue
const audioRecorderPlayer = new AudioRecorderPlayer();

const AudioPlayer: React.FC<AudioPlayerProps> = ({ audioUrl, duration = 0 }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [totalDuration, setTotalDuration] = useState(duration);

  const startPlayer = async () => {
    try {
      await audioRecorderPlayer.startPlayer(audioUrl);
      setIsPlaying(true);
      
      audioRecorderPlayer.addPlayBackListener((e: any) => {
        setCurrentPosition(e.currentPosition);
        setTotalDuration(e.duration);
        
        if (e.currentPosition === e.duration) {
          stopPlayer();
        }
      });
    } catch (error) {
      console.error('Error playing audio:', error);
    }
  };

  const stopPlayer = async () => {
    try {
      await audioRecorderPlayer.stopPlayer();
      audioRecorderPlayer.removePlayBackListener();
      setIsPlaying(false);
      setCurrentPosition(0);
    } catch (error) {
      console.error('Error stopping audio:', error);
    }
  };

  const pausePlayer = async () => {
    try {
      await audioRecorderPlayer.pausePlayer();
      setIsPlaying(false);
    } catch (error) {
      console.error('Error pausing audio:', error);
    }
  };

  const resumePlayer = async () => {
    try {
      await audioRecorderPlayer.resumePlayer();
      setIsPlaying(true);
    } catch (error) {
      console.error('Error resuming audio:', error);
    }
  };

  const handlePlayPause = () => {
    if (isPlaying) {
      pausePlayer();
    } else {
      if (currentPosition > 0) {
        resumePlayer();
      } else {
        startPlayer();
      }
    }
  };

  const formatTime = (milliseconds: number) => {
    const seconds = Math.floor(milliseconds / 1000);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  useEffect(() => {
    return () => {
      audioRecorderPlayer.stopPlayer();
      audioRecorderPlayer.removePlayBackListener();
    };
  }, []);

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

export default AudioPlayer;


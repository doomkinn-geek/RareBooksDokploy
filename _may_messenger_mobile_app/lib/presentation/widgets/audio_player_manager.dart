import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global manager for audio players to ensure only one audio plays at a time
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  String? _currentlyPlayingMessageId;
  Function? _stopCurrentPlayer;

  /// Register a player as currently playing
  void registerPlayer(String messageId, Function stopCallback) {
    // Stop previous player if it exists
    if (_currentlyPlayingMessageId != null && 
        _currentlyPlayingMessageId != messageId &&
        _stopCurrentPlayer != null) {
      _stopCurrentPlayer!();
    }
    
    _currentlyPlayingMessageId = messageId;
    _stopCurrentPlayer = stopCallback;
  }

  /// Unregister a player when it stops
  void unregisterPlayer(String messageId) {
    if (_currentlyPlayingMessageId == messageId) {
      _currentlyPlayingMessageId = null;
      _stopCurrentPlayer = null;
    }
  }

  /// Check if a specific message is currently playing
  bool isPlaying(String messageId) {
    return _currentlyPlayingMessageId == messageId;
  }

  /// Stop all players
  void stopAll() {
    if (_stopCurrentPlayer != null) {
      _stopCurrentPlayer!();
      _currentlyPlayingMessageId = null;
      _stopCurrentPlayer = null;
    }
  }
}

/// Provider for AudioPlayerManager
final audioPlayerManagerProvider = Provider<AudioPlayerManager>((ref) {
  return AudioPlayerManager();
});


import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Состояние текущего воспроизведения
class AudioPlaybackState {
  final String? messageId;
  final String? chatId;
  final String? senderName;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration? duration;
  final double speed;

  const AudioPlaybackState({
    this.messageId,
    this.chatId,
    this.senderName,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
  });

  bool get hasActivePlayback => messageId != null;
  
  double get progress {
    if (duration == null || duration!.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration!.inMilliseconds;
  }

  AudioPlaybackState copyWith({
    String? messageId,
    String? chatId,
    String? senderName,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? speed,
    bool clearMessage = false,
  }) {
    return AudioPlaybackState(
      messageId: clearMessage ? null : (messageId ?? this.messageId),
      chatId: clearMessage ? null : (chatId ?? this.chatId),
      senderName: clearMessage ? null : (senderName ?? this.senderName),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
    );
  }
}

/// Глобальный сервис для воспроизведения аудио сообщений
class GlobalAudioService extends StateNotifier<AudioPlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  
  Function(String messageId)? onPlaybackCompleted;
  
  GlobalAudioService() : super(const AudioPlaybackState()) {
    _setupPlayerListeners();
  }
  
  void _setupPlayerListeners() {
    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        state = state.copyWith(position: position);
      }
    });
    
    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        state = state.copyWith(duration: duration);
      }
    });
    
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (!mounted) return;
      
      state = state.copyWith(isPlaying: playerState.playing);
      
      if (playerState.processingState == ProcessingState.completed) {
        final completedMessageId = state.messageId;
        
        _player.seek(Duration.zero);
        _player.pause();
        
        state = state.copyWith(
          isPlaying: false, 
          position: Duration.zero,
          clearMessage: true,
        );
        
        if (completedMessageId != null && onPlaybackCompleted != null) {
          onPlaybackCompleted!(completedMessageId);
        }
      }
    });
  }
  
  /// Начать воспроизведение аудио сообщения
  Future<void> playMessage({
    required String messageId,
    required String chatId,
    required String audioUrl,
    String? senderName,
    String? localFilePath,
  }) async {
    try {
      if (state.messageId == messageId) {
        if (state.isPlaying) {
          await pause();
        } else {
          await resume();
        }
        return;
      }
      
      if (state.hasActivePlayback) {
        await _player.stop();
        state = const AudioPlaybackState();
      }
      
      state = state.copyWith(
        messageId: messageId,
        chatId: chatId,
        senderName: senderName,
        isLoading: true,
        isPlaying: false,
        position: Duration.zero,
        duration: null,
      );
      
      final source = localFilePath != null 
          ? AudioSource.file(localFilePath)
          : AudioSource.uri(Uri.parse(audioUrl));
      
      await _player.setAudioSource(source);
      await _player.setSpeed(state.speed);
      
      state = state.copyWith(isLoading: false);
      
      await _player.play();
      
      print('[GlobalAudio] Started playing: $messageId');
    } catch (e) {
      print('[GlobalAudio] Error playing: $e');
      state = state.copyWith(isLoading: false, clearMessage: true);
    }
  }
  
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print('[GlobalAudio] Error pausing: $e');
    }
  }
  
  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      print('[GlobalAudio] Error resuming: $e');
    }
  }
  
  Future<void> stop() async {
    try {
      await _player.stop();
      state = const AudioPlaybackState();
      print('[GlobalAudio] Stopped');
    } catch (e) {
      print('[GlobalAudio] Error stopping: $e');
    }
  }
  
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('[GlobalAudio] Error seeking: $e');
    }
  }
  
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } catch (e) {
      print('[GlobalAudio] Error setting speed: $e');
    }
  }
  
  Future<void> cycleSpeed() async {
    final newSpeed = switch (state.speed) {
      1.0 => 1.25,
      1.25 => 1.5,
      1.5 => 2.0,
      _ => 1.0,
    };
    await setSpeed(newSpeed);
  }
  
  bool isMessagePlaying(String messageId) {
    return state.messageId == messageId && state.isPlaying;
  }
  
  bool isCurrentMessage(String messageId) {
    return state.messageId == messageId;
  }
  
  double? getProgressForMessage(String messageId) {
    if (state.messageId != messageId) return null;
    return state.progress;
  }
  
  Duration? getPositionForMessage(String messageId) {
    if (state.messageId != messageId) return null;
    return state.position;
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final globalAudioServiceProvider = StateNotifierProvider<GlobalAudioService, AudioPlaybackState>((ref) {
  return GlobalAudioService();
});

final audioPlaybackStateProvider = Provider<AudioPlaybackState>((ref) {
  return ref.watch(globalAudioServiceProvider);
});

final isMessagePlayingProvider = Provider.family<bool, String>((ref, messageId) {
  final state = ref.watch(globalAudioServiceProvider);
  return state.messageId == messageId && state.isPlaying;
});

final isCurrentMessageProvider = Provider.family<bool, String>((ref, messageId) {
  final state = ref.watch(globalAudioServiceProvider);
  return state.messageId == messageId;
});

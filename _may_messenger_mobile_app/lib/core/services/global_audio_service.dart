import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../data/services/proximity_audio_service.dart';

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
/// Работает независимо от виджетов, поддерживает фоновое воспроизведение
class GlobalAudioService extends StateNotifier<AudioPlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  final ProximityAudioService _proximityService = ProximityAudioService();
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  
  // Callbacks for external listeners
  Function(bool isNearEar)? onProximityChanged;
  Function(String messageId)? onPlaybackCompleted;
  
  GlobalAudioService() : super(const AudioPlaybackState()) {
    _initAudioSession();
    _setupPlayerListeners();
    _setupProximityListener();
  }
  
  /// Setup proximity sensor listener for speaker/earpiece switching
  void _setupProximityListener() {
    _proximityService.addListener((isNearEar) {
      onProximityChanged?.call(isNearEar);
      print('[GlobalAudio] Proximity changed: ${isNearEar ? "EARPIECE" : "SPEAKER"}');
    });
  }
  
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      // Configure for media playback through speaker by default
      // ProximityAudioService will switch to earpiece when phone is near ear
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media, // Plays through speaker
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      
      // Handle audio interruptions (phone calls, other apps)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          // Interruption started - pause
          if (state.isPlaying) {
            pause();
          }
        }
      });
      
      print('[GlobalAudio] Audio session configured');
    } catch (e) {
      print('[GlobalAudio] Failed to configure audio session: $e');
    }
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
      
      // Handle playback completion
      if (playerState.processingState == ProcessingState.completed) {
        final completedMessageId = state.messageId;
        
        // Reset position but keep message info for mini-player
        _player.seek(Duration.zero);
        _player.pause();
        
        // Stop proximity sensor when playback completes
        _proximityService.stopListening();
        
        state = state.copyWith(isPlaying: false, position: Duration.zero);
        
        // Notify listeners
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
      // If same message is already playing, just toggle
      if (state.messageId == messageId) {
        if (state.isPlaying) {
          await pause();
        } else {
          await resume();
        }
        return;
      }
      
      // Stop current playback if different message
      if (state.hasActivePlayback) {
        await stop();
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
      
      // Use local file if available, otherwise stream from URL
      final source = localFilePath != null 
          ? AudioSource.file(localFilePath)
          : AudioSource.uri(Uri.parse(audioUrl));
      
      await _player.setAudioSource(source);
      await _player.setSpeed(state.speed);
      
      state = state.copyWith(isLoading: false);
      
      await _player.play();
      
      // Start proximity sensor for speaker/earpiece switching
      _proximityService.startListening();
      
      print('[GlobalAudio] Started playing message: $messageId');
    } catch (e) {
      print('[GlobalAudio] Error playing message: $e');
      state = state.copyWith(isLoading: false, clearMessage: true);
    }
  }
  
  /// Приостановить воспроизведение
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print('[GlobalAudio] Error pausing: $e');
    }
  }
  
  /// Продолжить воспроизведение
  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      print('[GlobalAudio] Error resuming: $e');
    }
  }
  
  /// Остановить воспроизведение и очистить состояние
  Future<void> stop() async {
    try {
      await _player.stop();
      // Stop proximity sensor when playback stops
      _proximityService.stopListening();
      state = const AudioPlaybackState(); // Reset to initial state
      print('[GlobalAudio] Stopped playback');
    } catch (e) {
      print('[GlobalAudio] Error stopping: $e');
    }
  }
  
  /// Перемотать на указанную позицию
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('[GlobalAudio] Error seeking: $e');
    }
  }
  
  /// Изменить скорость воспроизведения
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } catch (e) {
      print('[GlobalAudio] Error setting speed: $e');
    }
  }
  
  /// Циклическое изменение скорости: 1.0 -> 1.25 -> 1.5 -> 2.0 -> 1.0
  Future<void> cycleSpeed() async {
    final newSpeed = switch (state.speed) {
      1.0 => 1.25,
      1.25 => 1.5,
      1.5 => 2.0,
      _ => 1.0,
    };
    await setSpeed(newSpeed);
  }
  
  /// Проверить, воспроизводится ли конкретное сообщение
  bool isMessagePlaying(String messageId) {
    return state.messageId == messageId && state.isPlaying;
  }
  
  /// Проверить, является ли сообщение текущим (даже если на паузе)
  bool isCurrentMessage(String messageId) {
    return state.messageId == messageId;
  }
  
  /// Получить прогресс для конкретного сообщения
  double? getProgressForMessage(String messageId) {
    if (state.messageId != messageId) return null;
    return state.progress;
  }
  
  /// Получить позицию для конкретного сообщения
  Duration? getPositionForMessage(String messageId) {
    if (state.messageId != messageId) return null;
    return state.position;
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _proximityService.stopListening();
    _proximityService.dispose();
    _player.dispose();
    super.dispose();
  }
}

/// Provider для глобального аудио сервиса
final globalAudioServiceProvider = StateNotifierProvider<GlobalAudioService, AudioPlaybackState>((ref) {
  return GlobalAudioService();
});

/// Provider для получения только состояния воспроизведения (для UI)
final audioPlaybackStateProvider = Provider<AudioPlaybackState>((ref) {
  return ref.watch(globalAudioServiceProvider);
});

/// Provider для проверки, воспроизводится ли конкретное сообщение
final isMessagePlayingProvider = Provider.family<bool, String>((ref, messageId) {
  final state = ref.watch(globalAudioServiceProvider);
  return state.messageId == messageId && state.isPlaying;
});

/// Provider для проверки, является ли сообщение текущим (даже на паузе)
final isCurrentMessageProvider = Provider.family<bool, String>((ref, messageId) {
  final state = ref.watch(globalAudioServiceProvider);
  return state.messageId == messageId;
});


import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'background_audio_service.dart';
import 'proximity_audio_service.dart';

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
  final AudioOutputRoute outputRoute;
  final bool isBackgroundPlayback;
  final bool sequentialPlaybackEnabled; // Auto-play next audio in sequence

  const AudioPlaybackState({
    this.messageId,
    this.chatId,
    this.senderName,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.outputRoute = AudioOutputRoute.speaker,
    this.isBackgroundPlayback = false,
    this.sequentialPlaybackEnabled = true, // Enabled by default
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
    AudioOutputRoute? outputRoute,
    bool? isBackgroundPlayback,
    bool? sequentialPlaybackEnabled,
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
      outputRoute: outputRoute ?? this.outputRoute,
      isBackgroundPlayback: isBackgroundPlayback ?? this.isBackgroundPlayback,
      sequentialPlaybackEnabled: sequentialPlaybackEnabled ?? this.sequentialPlaybackEnabled,
    );
  }
}

/// Глобальный сервис для воспроизведения аудио сообщений
/// Интегрирован с BackgroundAudioService и ProximityAudioService
class GlobalAudioService extends StateNotifier<AudioPlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  final MayMessengerAudioHandler? _audioHandler;
  final ProximityAudioService _proximityService;
  
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  
  Function(String messageId)? onPlaybackCompleted;
  
  /// Callback to get next audio message info for sequential playback
  /// Returns (messageId, audioUrl, senderName, localFilePath) or null if no next audio
  Future<({String messageId, String audioUrl, String? senderName, String? localFilePath})?> Function(
    String currentMessageId, 
    String chatId
  )? getNextAudioMessage;
  
  GlobalAudioService(this._audioHandler, this._proximityService) 
      : super(const AudioPlaybackState()) {
    _setupPlayerListeners();
    _setupProximityListener();
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
        final completedChatId = state.chatId;
        final wasSequentialEnabled = state.sequentialPlaybackEnabled;
        
        _player.seek(Duration.zero);
        _player.pause();
        
        if (completedMessageId != null && onPlaybackCompleted != null) {
          onPlaybackCompleted!(completedMessageId);
        }
        
        // Try to play next audio in sequence if enabled
        if (wasSequentialEnabled && 
            completedMessageId != null && 
            completedChatId != null && 
            getNextAudioMessage != null) {
          // Get next audio message
          _playNextInSequence(completedMessageId, completedChatId);
        } else {
          // No sequential playback - stop and clean up
          _proximityService.stopMonitoring();
          state = state.copyWith(
            isPlaying: false, 
            position: Duration.zero,
            clearMessage: true,
          );
        }
      }
    });
  }
  
  void _setupProximityListener() {
    // Подписываемся на изменения маршрута аудио
    _proximityService.onRouteChanged = (route) {
      if (mounted) {
        state = state.copyWith(outputRoute: route);
        print('[GlobalAudio] Audio route changed to: $route');
      }
    };
    
    // Подписываемся на событие убирания телефона от уха - пауза аудио
    _proximityService.onRemovedFromEar = () {
      if (mounted && state.isPlaying && state.outputRoute == AudioOutputRoute.earpiece) {
        print('[GlobalAudio] Phone removed from ear while playing via earpiece, pausing...');
        pause();
      }
    };
  }
  
  /// Начать воспроизведение аудио сообщения
  Future<void> playMessage({
    required String messageId,
    required String chatId,
    required String audioUrl,
    String? senderName,
    String? localFilePath,
  }) async {
    print('[GlobalAudio] ========== PLAY CALLED ==========');
    print('[GlobalAudio] messageId: $messageId');
    print('[GlobalAudio] audioUrl: $audioUrl');
    print('[GlobalAudio] _proximityService: $_proximityService');
    print('[GlobalAudio] _proximityService.isMonitoring: ${_proximityService.isMonitoring}');
    
    try {
      // Если это то же сообщение - переключить play/pause
      if (state.messageId == messageId) {
        if (state.isPlaying) {
          await pause();
        } else {
          await resume();
        }
        return;
      }
      
      // Остановить текущее воспроизведение
      if (state.hasActivePlayback) {
        await _player.stop();
        await _proximityService.stopMonitoring();
        state = const AudioPlaybackState();
      }
      
      // Установить состояние загрузки
      state = state.copyWith(
        messageId: messageId,
        chatId: chatId,
        senderName: senderName,
        isLoading: true,
        isPlaying: false,
        position: Duration.zero,
        duration: null,
      );
      
      // Загрузить аудио источник
      final source = localFilePath != null 
          ? AudioSource.file(localFilePath)
          : AudioSource.uri(Uri.parse(audioUrl));
      
      await _player.setAudioSource(source);
      await _player.setSpeed(state.speed);
      
      // Обновить MediaSession (если доступен)
      if (_audioHandler != null) {
        final duration = _player.duration;
        await _audioHandler.updateAudioMediaItem(
          messageId: messageId,
          chatId: chatId,
          senderName: senderName ?? 'Unknown',
          duration: duration,
        );
      }
      
      state = state.copyWith(isLoading: false);
      
      // Запустить мониторинг proximity sensor ПЕРЕД воспроизведением
      // Это позволяет определить, если телефон уже у уха при первом нажатии
      await _proximityService.startMonitoring();
      
      // Небольшая задержка для получения первого события от датчика
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Если телефон уже у уха, переключиться на earpiece сразу
      if (_proximityService.isNearEar && _proximityService.currentRoute != AudioOutputRoute.earpiece) {
        print('[GlobalAudio] Phone already near ear at start, switching to earpiece');
        // ProximityService уже должен был обработать это, но проверим
      }
      
      // Запустить воспроизведение
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
      // AudioHandler автоматически синхронизирован через listeners
    } catch (e) {
      print('[GlobalAudio] Error pausing: $e');
    }
  }
  
  Future<void> resume() async {
    try {
      await _player.play();
      
      // Возобновить proximity monitoring если был остановлен
      if (!_proximityService.isMonitoring && state.hasActivePlayback) {
        await _proximityService.startMonitoring();
      }
    } catch (e) {
      print('[GlobalAudio] Error resuming: $e');
    }
  }
  
  Future<void> stop() async {
    try {
      await _player.stop();
      await _proximityService.stopMonitoring();
      
      state = const AudioPlaybackState();
      print('[GlobalAudio] Stopped');
    } catch (e) {
      print('[GlobalAudio] Error stopping: $e');
    }
  }
  
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      // AudioHandler автоматически синхронизирован
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
  
  /// Play next audio message in sequence
  Future<void> _playNextInSequence(String completedMessageId, String chatId) async {
    try {
      if (getNextAudioMessage == null) {
        _proximityService.stopMonitoring();
        state = state.copyWith(isPlaying: false, position: Duration.zero, clearMessage: true);
        return;
      }
      
      final nextAudio = await getNextAudioMessage!(completedMessageId, chatId);
      
      if (nextAudio == null) {
        // No more audio messages in sequence
        print('[GlobalAudio] No more audio messages in sequence, stopping');
        _proximityService.stopMonitoring();
        state = state.copyWith(isPlaying: false, position: Duration.zero, clearMessage: true);
        return;
      }
      
      print('[GlobalAudio] Playing next audio in sequence: ${nextAudio.messageId}');
      
      // Play next audio without restarting proximity monitoring (already running)
      await _playNextWithoutProximityRestart(
        messageId: nextAudio.messageId,
        chatId: chatId,
        audioUrl: nextAudio.audioUrl,
        senderName: nextAudio.senderName,
        localFilePath: nextAudio.localFilePath,
      );
    } catch (e) {
      print('[GlobalAudio] Error playing next in sequence: $e');
      _proximityService.stopMonitoring();
      state = state.copyWith(isPlaying: false, position: Duration.zero, clearMessage: true);
    }
  }
  
  /// Play next audio without restarting proximity monitoring
  Future<void> _playNextWithoutProximityRestart({
    required String messageId,
    required String chatId,
    required String audioUrl,
    String? senderName,
    String? localFilePath,
  }) async {
    try {
      // Update state for new message
      state = state.copyWith(
        messageId: messageId,
        chatId: chatId,
        senderName: senderName,
        isLoading: true,
        isPlaying: false,
        position: Duration.zero,
        duration: null,
      );
      
      // Load audio source
      final source = localFilePath != null 
          ? AudioSource.file(localFilePath)
          : AudioSource.uri(Uri.parse(audioUrl));
      
      await _player.setAudioSource(source);
      await _player.setSpeed(state.speed);
      
      // Update MediaSession if available
      if (_audioHandler != null) {
        final duration = _player.duration;
        await _audioHandler.updateAudioMediaItem(
          messageId: messageId,
          chatId: chatId,
          senderName: senderName ?? 'Unknown',
          duration: duration,
        );
      }
      
      state = state.copyWith(isLoading: false);
      
      // Start playback
      await _player.play();
      
      print('[GlobalAudio] Started playing next: $messageId');
    } catch (e) {
      print('[GlobalAudio] Error playing next: $e');
      _proximityService.stopMonitoring();
      state = state.copyWith(isLoading: false, clearMessage: true);
    }
  }
  
  /// Toggle sequential playback on/off
  void setSequentialPlayback(bool enabled) {
    if (mounted) {
      state = state.copyWith(sequentialPlaybackEnabled: enabled);
      print('[GlobalAudio] Sequential playback: $enabled');
    }
  }
  
  /// Обновить флаг фонового воспроизведения (вызывается из lifecycle observer)
  void setBackgroundPlayback(bool isBackground) {
    if (mounted) {
      state = state.copyWith(isBackgroundPlayback: isBackground);
    }
  }
  
  /// Получить доступ к AudioPlayer (для AudioHandler)
  AudioPlayer get player => _player;
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _proximityService.dispose();
    _player.dispose();
    super.dispose();
  }
}

/// Provider для GlobalAudioService (с зависимостями)
final globalAudioServiceProvider = StateNotifierProvider<GlobalAudioService, AudioPlaybackState>((ref) {
  print('[GlobalAudio] ========== INITIALIZING GlobalAudioService ==========');
  
  // Получаем зависимости
  MayMessengerAudioHandler? audioHandler;
  try {
    audioHandler = ref.read(audioHandlerProvider);
    print('[GlobalAudio] AudioHandler initialized successfully');
  } catch (e) {
    // AudioHandler может быть не инициализирован на старте
    print('[GlobalAudio] AudioHandler not yet initialized: $e');
    audioHandler = null;
  }
  
  final proximityService = ref.read(proximityAudioServiceProvider);
  print('[GlobalAudio] ProximityService initialized: $proximityService');
  
  final service = GlobalAudioService(audioHandler, proximityService);
  print('[GlobalAudio] ========== GlobalAudioService READY ==========');
  
  // Подключаем callbacks от AudioHandler к GlobalAudioService
  if (audioHandler != null) {
    audioHandler.onPositionChanged = (position) {
      // Уже обрабатывается через positionStream
    };
    
    audioHandler.onDurationChanged = (duration) {
      // Уже обрабатывается через durationStream
    };
    
    audioHandler.onPlayingChanged = (playing) {
      // Уже обрабатывается через playerStateStream
    };
    
    audioHandler.onCompleted = () {
      // Уже обрабатывается через playerStateStream
    };
  }
  
  return service;
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

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background Audio Handler для интеграции с системными медиа-контролами
/// Обеспечивает фоновое воспроизведение с MediaSession (Android) и NowPlaying (iOS)
class MayMessengerAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  
  // Callback для синхронизации с GlobalAudioService
  Function(Duration position)? onPositionChanged;
  Function(Duration duration)? onDurationChanged;
  Function(bool playing)? onPlayingChanged;
  Function()? onCompleted;

  MayMessengerAudioHandler(this._player) {
    _setupPlayerListeners();
    _configureAudioSession();
  }

  /// Настройка audio session для голосовых сообщений
  /// По умолчанию используем media usage для воспроизведения через speaker
  /// При приближении к уху ProximityAudioService переключит на voiceCommunication
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | 
                                        AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Обработка прерываний (входящие звонки и т.д.)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Уменьшить громкость
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Приостановить воспроизведение
              pause();
              break;
          }
        } else {
          // Восстановить после прерывания
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              // Не автоматически возобновляем после звонка
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Обработка изменения аудио-устройств
      session.becomingNoisyEventStream.listen((_) {
        // Наушники отключены - ставим на паузу
        pause();
      });
    } catch (e) {
      print('[AudioHandler] Error configuring audio session: $e');
    }
  }

  void _setupPlayerListeners() {
    // Синхронизация позиции
    _positionSubscription = _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
      onPositionChanged?.call(position);
    });

    // Синхронизация длительности
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null) {
        onDurationChanged?.call(duration);
      }
    });

    // Синхронизация состояния воспроизведения
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      final playing = playerState.playing;
      onPlayingChanged?.call(playing);

      // Обновление MediaSession
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: _mapProcessingState(playerState.processingState),
      ));

      // Обработка завершения воспроизведения
      if (playerState.processingState == ProcessingState.completed) {
        onCompleted?.call();
      }
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Обновить метаданные воспроизводимого сообщения
  Future<void> updateAudioMediaItem({
    required String messageId,
    required String chatId,
    required String senderName,
    Duration? duration,
  }) async {
    mediaItem.add(MediaItem(
      id: messageId,
      album: 'Чат: $chatId',
      title: 'Голосовое сообщение',
      artist: senderName,
      duration: duration,
      artUri: null,
    ));
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      print('[AudioHandler] Error playing: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print('[AudioHandler] Error pausing: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      
      // Очистить MediaSession
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));
      mediaItem.add(null);
    } catch (e) {
      print('[AudioHandler] Error stopping: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('[AudioHandler] Error seeking: $e');
    }
  }

  Future<void> skipForward() async {
    final currentPosition = _player.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    await seek(newPosition);
  }

  Future<void> skipBackward() async {
    final currentPosition = _player.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    await seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  /// Обработка закрытия приложения
  @override
  Future<void> onTaskRemoved() async {
    // Остановить воспроизведение при закрытии приложения
    await stop();
    await super.onTaskRemoved();
  }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();
  }
}

/// Provider для AudioHandler (будет инициализирован в main.dart)
final audioHandlerProvider = Provider<MayMessengerAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be initialized in main.dart');
});


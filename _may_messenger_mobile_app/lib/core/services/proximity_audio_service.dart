import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

/// Типы выхода аудио
enum AudioOutputRoute {
  speaker,    // Громкоговоритель
  earpiece,   // Разговорный динамик (у уха)
  bluetooth,  // Bluetooth устройство
}

/// Сервис управления датчиком приближения и маршрутизацией аудио
/// Автоматически переключает аудио между динамиком и наушником при поднесении к уху
class ProximityAudioService {
  static const MethodChannel _audioChannel = MethodChannel('ru.rare_books.messenger/audio_routing');
  
  StreamSubscription<int>? _proximitySub;
  bool _isNearEar = false;
  bool _isMonitoring = false;
  AudioOutputRoute _currentRoute = AudioOutputRoute.speaker;
  
  // Callback для уведомления об изменении маршрута
  Function(AudioOutputRoute route)? onRouteChanged;

  AudioOutputRoute get currentRoute => _currentRoute;
  bool get isNearEar => _isNearEar;
  bool get isMonitoring => _isMonitoring;

  /// Начать мониторинг датчика приближения
  Future<void> startMonitoring() async {
    print('[ProximityAudioService] startMonitoring called. isMonitoring=$_isMonitoring');
    
    if (_isMonitoring) {
      print('[ProximityAudioService] Already monitoring, skipping');
      return;
    }

    try {
      _isMonitoring = true;
      print('[ProximityAudioService] Starting proximity sensor monitoring...');
      
      // Подписываемся на события датчика приближения
      _proximitySub = ProximitySensor.events.listen((int value) {
        final wasNearEar = _isNearEar;
        _isNearEar = value > 0;
        
        print('[ProximityAudioService] Proximity sensor event: value=$value, isNearEar=$_isNearEar, wasNearEar=$wasNearEar');
        
        // Переключаем аудио только если состояние изменилось
        if (wasNearEar != _isNearEar) {
          if (_isNearEar) {
            print('[ProximityAudioService] Phone near ear detected, switching to earpiece...');
            _setAudioRouteEarpiece();
          } else {
            print('[ProximityAudioService] Phone away from ear, switching to speaker...');
            _setAudioRouteSpeaker();
          }
        }
      });
      
      print('[ProximityAudioService] Proximity sensor monitoring started successfully');
    } catch (e) {
      print('[ProximityAudioService] Failed to start monitoring: $e');
      _isMonitoring = false;
    }
  }

  /// Остановить мониторинг
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    await _proximitySub?.cancel();
    _proximitySub = null;
    _isMonitoring = false;

    // Восстанавливаем нормальный режим аудио
    await _restoreAudioRoute();
  }

  /// Переключить на разговорный динамик (earpiece)
  Future<void> _setAudioRouteEarpiece() async {
    if (_currentRoute == AudioOutputRoute.earpiece) return;

    try {
      print('ProximityAudioService: Attempting to switch to earpiece (Platform.isAndroid=${Platform.isAndroid})');
      
      if (Platform.isAndroid) {
        // СНАЧАЛА переконфигурируем audio_session на voiceCommunication
        print('ProximityAudioService: Reconfiguring audio_session for earpiece');
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));
        
        // ЗАТЕМ вызываем нативный код для настройки AudioManager
        print('ProximityAudioService: Invoking setAudioRouteEarpiece on channel');
        final result = await _audioChannel.invokeMethod('setAudioRouteEarpiece');
        print('ProximityAudioService: setAudioRouteEarpiece result: $result');
      } else if (Platform.isIOS) {
        // Для iOS используем audio_session
        print('ProximityAudioService: Using audio_session for iOS');
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));
        
        // iOS автоматически маршрутизирует на earpiece в режиме voiceChat
      }

      _currentRoute = AudioOutputRoute.earpiece;
      onRouteChanged?.call(_currentRoute);
      print('ProximityAudioService: Switched to earpiece');
    } catch (e) {
      print('ProximityAudioService: Failed to switch to earpiece: $e');
    }
  }

  /// Переключить на основной динамик (speaker)
  Future<void> _setAudioRouteSpeaker() async {
    if (_currentRoute == AudioOutputRoute.speaker) return;

    try {
      print('ProximityAudioService: Attempting to switch to speaker (Platform.isAndroid=${Platform.isAndroid})');
      
      if (Platform.isAndroid) {
        // СНАЧАЛА переконфигурируем audio_session на media usage
        print('ProximityAudioService: Reconfiguring audio_session for speaker');
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        
        // ЗАТЕМ вызываем нативный код для настройки AudioManager
        print('ProximityAudioService: Invoking setAudioRouteSpeaker on channel');
        final result = await _audioChannel.invokeMethod('setAudioRouteSpeaker');
        print('ProximityAudioService: setAudioRouteSpeaker result: $result');
      } else if (Platform.isIOS) {
        // Для iOS используем audio_session
        print('ProximityAudioService: Using audio_session for iOS');
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
      }

      _currentRoute = AudioOutputRoute.speaker;
      onRouteChanged?.call(_currentRoute);
      print('ProximityAudioService: Switched to speaker');
    } catch (e) {
      print('ProximityAudioService: Failed to switch to speaker: $e');
    }
  }

  /// Восстановить нормальный режим аудио
  Future<void> _restoreAudioRoute() async {
    try {
      if (Platform.isAndroid) {
        // Используем Platform Channel для Android
        await _audioChannel.invokeMethod('restoreAudioRoute');
      } else if (Platform.isIOS) {
        // Для iOS восстанавливаем стандартный режим воспроизведения
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
      }

      _currentRoute = AudioOutputRoute.speaker;
      onRouteChanged?.call(_currentRoute);
      print('ProximityAudioService: Audio route restored');
    } catch (e) {
      print('ProximityAudioService: Failed to restore audio route: $e');
    }
  }

  /// Освободить ресурсы
  Future<void> dispose() async {
    await stopMonitoring();
  }
}

/// Riverpod provider для глобального доступа к ProximityAudioService
final proximityAudioServiceProvider = Provider<ProximityAudioService>((ref) {
  print('[ProximityAudioService] ========== CREATING ProximityAudioService ==========');
  final service = ProximityAudioService();
  ref.onDispose(() {
    print('[ProximityAudioService] ========== DISPOSING ProximityAudioService ==========');
    service.dispose();
  });
  print('[ProximityAudioService] ========== ProximityAudioService READY ==========');
  return service;
});

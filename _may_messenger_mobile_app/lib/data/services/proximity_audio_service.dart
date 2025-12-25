import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

/// Service to manage audio playback mode based on proximity sensor
/// Switches between speaker and earpiece when phone is held near ear
class ProximityAudioService {
  static final ProximityAudioService _instance = ProximityAudioService._internal();
  factory ProximityAudioService() => _instance;
  ProximityAudioService._internal();
  
  StreamSubscription<int>? _proximitySubscription;
  bool _isNearEar = false;
  bool _isListening = false;
  AudioSession? _audioSession;
  
  // Callbacks for UI updates
  final List<Function(bool isNearEar)> _listeners = [];
  
  /// Whether the phone is currently near the ear
  bool get isNearEar => _isNearEar;
  
  /// Whether the service is actively listening to proximity sensor
  bool get isListening => _isListening;
  
  /// Add a listener for proximity changes
  void addListener(Function(bool isNearEar) listener) {
    _listeners.add(listener);
  }
  
  /// Remove a listener
  void removeListener(Function(bool isNearEar) listener) {
    _listeners.remove(listener);
  }
  
  /// Notify all listeners about proximity change
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener(_isNearEar);
      } catch (e) {
        print('[ProximityAudio] Error notifying listener: $e');
      }
    }
  }
  
  /// Start listening to proximity sensor
  /// Call this when audio playback starts
  Future<void> startListening() async {
    if (_isListening) return;
    
    // Only support Android and iOS
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('[ProximityAudio] Proximity sensor not supported on this platform');
      return;
    }
    
    try {
      // Initialize audio session
      _audioSession = await AudioSession.instance;
      
      // Start listening to proximity sensor
      _proximitySubscription = ProximitySensor.events.listen((int event) {
        // event > 0 means object is near (phone near ear)
        final wasNearEar = _isNearEar;
        _isNearEar = event > 0;
        
        if (wasNearEar != _isNearEar) {
          print('[ProximityAudio] Proximity changed: ${_isNearEar ? "NEAR" : "FAR"}');
          _updateAudioRoute();
          _notifyListeners();
        }
      });
      
      _isListening = true;
      print('[ProximityAudio] Started listening to proximity sensor');
    } catch (e) {
      print('[ProximityAudio] Failed to start proximity sensor: $e');
    }
  }
  
  /// Stop listening to proximity sensor
  /// Call this when audio playback stops
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await _proximitySubscription?.cancel();
      _proximitySubscription = null;
      _isListening = false;
      _isNearEar = false;
      
      // Reset audio route to speaker
      await _setAudioRoute(speakerMode: true);
      
      print('[ProximityAudio] Stopped listening to proximity sensor');
    } catch (e) {
      print('[ProximityAudio] Error stopping proximity sensor: $e');
    }
  }
  
  /// Update audio route based on proximity
  Future<void> _updateAudioRoute() async {
    await _setAudioRoute(speakerMode: !_isNearEar);
  }
  
  /// Set audio route to speaker or earpiece
  Future<void> _setAudioRoute({required bool speakerMode}) async {
    if (_audioSession == null) {
      _audioSession = await AudioSession.instance;
    }
    
    try {
      if (speakerMode) {
        // Use media playback mode (speaker)
        await _audioSession!.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ));
        print('[ProximityAudio] Audio route set to SPEAKER');
      } else {
        // Use voice communication mode (earpiece)
        await _audioSession!.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ));
        print('[ProximityAudio] Audio route set to EARPIECE');
      }
    } catch (e) {
      print('[ProximityAudio] Failed to set audio route: $e');
    }
  }
  
  /// Force speaker mode (for when user wants speaker regardless of proximity)
  Future<void> forceSpeakerMode() async {
    await _setAudioRoute(speakerMode: true);
  }
  
  /// Force earpiece mode
  Future<void> forceEarpieceMode() async {
    await _setAudioRoute(speakerMode: false);
  }
  
  /// Dispose the service
  void dispose() {
    stopListening();
    _listeners.clear();
  }
}

/// Provider for ProximityAudioService
final proximityAudioServiceProvider = Provider<ProximityAudioService>((ref) {
  return ProximityAudioService();
});


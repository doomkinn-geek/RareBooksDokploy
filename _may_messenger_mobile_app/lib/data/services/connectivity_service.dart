import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatus = StreamController<bool>.broadcast();
  
  bool _isConnected = true;
  StreamSubscription<ConnectivityResult>? _subscription;
  
  ConnectivityService() {
    _init();
  }
  
  Future<void> _init() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    _connectionStatus.add(_isConnected);
    
    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;
      
      if (wasConnected != _isConnected) {
        print('[Connectivity] Status changed: ${_isConnected ? "ONLINE" : "OFFLINE"}');
        _connectionStatus.add(_isConnected);
      }
    });
  }
  
  /// Get current connectivity status
  bool get isConnected => _isConnected;
  
  /// Stream of connectivity status changes
  Stream<bool> get connectionStream => _connectionStatus.stream;
  
  /// Check connectivity now
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      print('[Connectivity] Failed to check connectivity: $e');
      return false;
    }
  }
  
  void dispose() {
    _subscription?.cancel();
    _connectionStatus.close();
  }
}


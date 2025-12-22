import 'dart:async';
import 'package:logger/logger.dart';

/// Service for managing typing indicators with debouncing
/// Prevents spamming the server with typing events
class TypingIndicatorService {
  final Logger _logger = Logger();
  final Function(String chatId, bool isTyping) _sendTypingIndicator;
  
  // Debouncing configuration
  static const Duration typingDebounceDelay = Duration(milliseconds: 300);
  static const Duration typingStopDelay = Duration(seconds: 3);
  
  // State tracking
  final Map<String, Timer?> _debounceTimers = {};
  final Map<String, Timer?> _stopTimers = {};
  final Map<String, bool> _currentTypingStates = {};

  TypingIndicatorService(this._sendTypingIndicator);

  /// User started typing in a chat
  /// Debounces the event to avoid spamming
  void onTyping(String chatId) {
    // Cancel existing debounce timer
    _debounceTimers[chatId]?.cancel();
    
    // Set new debounce timer
    _debounceTimers[chatId] = Timer(typingDebounceDelay, () {
      _setTyping(chatId, true);
    });
    
    // Reset stop timer (user is still typing)
    _resetStopTimer(chatId);
  }

  /// User stopped typing in a chat (explicit)
  void onStoppedTyping(String chatId) {
    _setTyping(chatId, false);
    _debounceTimers[chatId]?.cancel();
    _stopTimers[chatId]?.cancel();
  }

  /// Internal method to set typing state
  void _setTyping(String chatId, bool isTyping) {
    // Only send if state changed
    if (_currentTypingStates[chatId] == isTyping) {
      return;
    }

    _currentTypingStates[chatId] = isTyping;
    
    try {
      _sendTypingIndicator(chatId, isTyping);
      _logger.d('[TypingIndicator] Sent typing=$isTyping for chat $chatId');
    } catch (e) {
      _logger.e('[TypingIndicator] Error sending typing indicator', error: e);
    }

    // If started typing, set auto-stop timer
    if (isTyping) {
      _resetStopTimer(chatId);
    }
  }

  /// Reset the auto-stop timer
  void _resetStopTimer(String chatId) {
    _stopTimers[chatId]?.cancel();
    
    _stopTimers[chatId] = Timer(typingStopDelay, () {
      _setTyping(chatId, false);
    });
  }

  /// Clean up timers for a specific chat
  void cleanupChat(String chatId) {
    _debounceTimers[chatId]?.cancel();
    _stopTimers[chatId]?.cancel();
    _debounceTimers.remove(chatId);
    _stopTimers.remove(chatId);
    _currentTypingStates.remove(chatId);
    _logger.d('[TypingIndicator] Cleaned up chat $chatId');
  }

  /// Dispose all resources
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    for (final timer in _stopTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    _stopTimers.clear();
    _currentTypingStates.clear();
    _logger.d('[TypingIndicator] Disposed');
  }

  /// Get statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'activeChats': _currentTypingStates.length,
      'typingChats': _currentTypingStates.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
    };
  }
}


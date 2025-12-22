import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

class TypingUser {
  final String userId;
  final String userName;
  final DateTime lastTypingAt;
  
  TypingUser({required this.userId, required this.userName, required this.lastTypingAt});
}

class TypingState {
  final Map<String, List<TypingUser>> typingUsersByChat; // chatId -> List<TypingUser>
  
  TypingState({this.typingUsersByChat = const {}});
  
  TypingState copyWith({Map<String, List<TypingUser>>? typingUsersByChat}) {
    return TypingState(
      typingUsersByChat: typingUsersByChat ?? this.typingUsersByChat,
    );
  }
  
  List<TypingUser> getTypingUsers(String chatId) {
    return typingUsersByChat[chatId] ?? [];
  }
}

final typingProvider = StateNotifierProvider<TypingNotifier, TypingState>((ref) {
  return TypingNotifier();
});

class TypingNotifier extends StateNotifier<TypingState> {
  Timer? _cleanupTimer;
  
  TypingNotifier() : super(TypingState()) {
    // Start periodic cleanup of stale typing users
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      cleanupStaleTypingUsers();
    });
  }
  
  void setUserTyping(String chatId, String userId, String userName, bool isTyping) {
    final currentUsers = state.typingUsersByChat[chatId] ?? [];
    
    if (isTyping) {
      // Add or update user
      final existingIndex = currentUsers.indexWhere((u) => u.userId == userId);
      final newUser = TypingUser(userId: userId, userName: userName, lastTypingAt: DateTime.now());
      
      List<TypingUser> updatedUsers;
      if (existingIndex >= 0) {
        updatedUsers = [...currentUsers];
        updatedUsers[existingIndex] = newUser;
      } else {
        updatedUsers = [...currentUsers, newUser];
      }
      
      state = state.copyWith(
        typingUsersByChat: {...state.typingUsersByChat, chatId: updatedUsers}
      );
    } else {
      // Remove user
      final updatedUsers = currentUsers.where((u) => u.userId != userId).toList();
      state = state.copyWith(
        typingUsersByChat: {...state.typingUsersByChat, chatId: updatedUsers}
      );
    }
  }
  
  void cleanupStaleTypingUsers() {
    // Remove users who haven't typed in 5 seconds
    final now = DateTime.now();
    final updatedMap = <String, List<TypingUser>>{};
    
    for (var entry in state.typingUsersByChat.entries) {
      final activeUsers = entry.value
          .where((u) => now.difference(u.lastTypingAt).inSeconds < 5)
          .toList();
      
      if (activeUsers.isNotEmpty) {
        updatedMap[entry.key] = activeUsers;
      }
    }
    
    if (updatedMap.length != state.typingUsersByChat.length) {
      state = state.copyWith(typingUsersByChat: updatedMap);
    }
  }
  
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}


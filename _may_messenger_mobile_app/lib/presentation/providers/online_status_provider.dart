import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for tracking online users
final onlineUsersProvider = StateNotifierProvider<OnlineUsersNotifier, Set<String>>((ref) {
  return OnlineUsersNotifier();
});

class OnlineUsersNotifier extends StateNotifier<Set<String>> {
  OnlineUsersNotifier() : super({});
  
  void setUserOnline(String userId, bool isOnline) {
    if (isOnline) {
      state = {...state, userId};
    } else {
      state = state.where((id) => id != userId).toSet();
    }
  }
}

/// Provider for tracking last seen timestamps
final userLastSeenProvider = StateNotifierProvider.family<UserLastSeenNotifier, DateTime?, String>((ref, userId) {
  return UserLastSeenNotifier();
});

class UserLastSeenNotifier extends StateNotifier<DateTime?> {
  UserLastSeenNotifier() : super(null);
  
  void setLastSeen(DateTime? lastSeen) {
    state = lastSeen;
  }
}

/// Global map for last seen times (more efficient than family provider for bulk updates)
final lastSeenMapProvider = StateNotifierProvider<LastSeenMapNotifier, Map<String, DateTime>>((ref) {
  return LastSeenMapNotifier();
});

class LastSeenMapNotifier extends StateNotifier<Map<String, DateTime>> {
  LastSeenMapNotifier() : super({});
  
  void setLastSeen(String userId, DateTime lastSeen) {
    state = {...state, userId: lastSeen};
  }
  
  DateTime? getLastSeen(String userId) {
    return state[userId];
  }
}


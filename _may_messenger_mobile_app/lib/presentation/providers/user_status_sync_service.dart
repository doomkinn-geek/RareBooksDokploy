import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'online_status_provider.dart';
import 'chats_provider.dart';
import 'auth_provider.dart';

final userStatusSyncServiceProvider = Provider<UserStatusSyncService>((ref) {
  return UserStatusSyncService(ref);
});

class UserStatusSyncService {
  final Ref _ref;
  Timer? _periodicSyncTimer;
  bool _isSyncing = false; // Prevent concurrent syncs
  
  UserStatusSyncService(this._ref);
  
  /// Load initial statuses for all users in current chats
  Future<void> loadInitialStatuses() async {
    if (_isSyncing) {
      print('[UserStatusSync] Already syncing, skipping...');
      return;
    }
    
    _isSyncing = true;
    
    try {
      print('[UserStatusSync] Loading initial statuses...');
      
      final chatsState = _ref.read(chatsProvider);
      final userIds = <String>{};
      
      // Collect all unique user IDs from chats
      for (final chat in chatsState.chats) {
        if (chat.otherParticipantId != null) {
          userIds.add(chat.otherParticipantId!);
        }
      }
      
      if (userIds.isEmpty) {
        print('[UserStatusSync] No users to sync');
        return;
      }
      
      print('[UserStatusSync] Syncing ${userIds.length} users');
      
      // Fetch statuses from API
      final userRepository = _ref.read(userRepositoryProvider);
      final statuses = await userRepository.getUsersStatus(userIds.toList());
      
      // Update providers
      final onlineUsersNotifier = _ref.read(onlineUsersProvider.notifier);
      final lastSeenMapNotifier = _ref.read(lastSeenMapProvider.notifier);
      
      for (final status in statuses) {
        onlineUsersNotifier.setUserOnline(status.userId, status.isOnline);
        
        if (status.lastSeenAt != null) {
          lastSeenMapNotifier.setLastSeen(status.userId, status.lastSeenAt!);
        }
      }
      
      print('[UserStatusSync] Successfully synced ${statuses.length} statuses');
    } catch (e) {
      print('[UserStatusSync] Error loading statuses: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Start periodic status sync (every 10 minutes as fallback)
  void startPeriodicSync() {
    stopPeriodicSync();
    
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      loadInitialStatuses();
    });
    
    print('[UserStatusSync] Periodic sync started (10 min interval)');
  }
  
  /// Stop periodic status sync
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
  
  void dispose() {
    stopPeriodicSync();
  }
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/datasources/local_datasource.dart';
import 'auth_provider.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) {
    return ProfileNotifier(
      ref.read(apiDataSourceProvider),
      ref.read(localDataSourceProvider),
    );
  },
);

class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;
  final String? cachedUserId; // Cached user ID for offline mode

  ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.cachedUserId,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    String? cachedUserId,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cachedUserId: cachedUserId ?? this.cachedUserId,
    );
  }
  
  /// Get user ID - uses profile.id if available, otherwise cached userId
  /// This ensures isMe check works in offline mode
  String? get userId => profile?.id ?? cachedUserId;
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final dynamic _apiDataSource;
  final LocalDataSource _localDataSource;

  ProfileNotifier(this._apiDataSource, this._localDataSource) : super(ProfileState()) {
    _loadCachedUserId();
    loadProfile();
  }
  
  /// Load cached user ID for offline mode
  Future<void> _loadCachedUserId() async {
    try {
      final cachedId = await _localDataSource.getCurrentUserId();
      if (cachedId != null) {
        state = state.copyWith(cachedUserId: cachedId);
        print('[Profile] Loaded cached user ID: $cachedId');
      }
    } catch (e) {
      print('[Profile] Failed to load cached user ID: $e');
    }
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _apiDataSource.getUserProfile();
      
      // Cache user ID for offline mode
      if (profile.id != null) {
        await _localDataSource.saveCurrentUserId(profile.id);
        print('[Profile] Saved user ID to cache: ${profile.id}');
      }
      
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        cachedUserId: profile.id, // Update cached ID
      );
    } catch (e) {
      print('[Profile] Failed to load profile: $e');
      
      // In offline mode, keep the cached user ID
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadProfile();
  }
  
  /// Clear cached user ID (call on logout)
  Future<void> clearCache() async {
    try {
      await _localDataSource.clearCurrentUserId();
      state = state.copyWith(cachedUserId: null);
    } catch (e) {
      print('[Profile] Failed to clear cached user ID: $e');
    }
  }
}


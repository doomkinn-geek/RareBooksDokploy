import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import 'auth_provider.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) {
    return ProfileNotifier(ref.read(apiDataSourceProvider));
  },
);

class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final dynamic _apiDataSource;

  ProfileNotifier(this._apiDataSource) : super(ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _apiDataSource.getUserProfile();
      state = state.copyWith(
        profile: profile,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadProfile();
  }
}


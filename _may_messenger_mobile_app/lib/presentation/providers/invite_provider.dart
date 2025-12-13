import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invite_link_model.dart';
import 'auth_provider.dart';

final inviteProvider = StateNotifierProvider<InviteNotifier, InviteState>(
  (ref) {
    return InviteNotifier(ref.read(apiDataSourceProvider));
  },
);

class InviteState {
  final List<InviteLink> inviteLinks;
  final bool isLoading;
  final bool isCreating;
  final String? error;

  InviteState({
    this.inviteLinks = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.error,
  });

  InviteState copyWith({
    List<InviteLink>? inviteLinks,
    bool? isLoading,
    bool? isCreating,
    String? error,
  }) {
    return InviteState(
      inviteLinks: inviteLinks ?? this.inviteLinks,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: error,
    );
  }

  /// Получить только валидные invite links
  List<InviteLink> get validInviteLinks {
    return inviteLinks.where((link) => link.isValid).toList();
  }
}

class InviteNotifier extends StateNotifier<InviteState> {
  final dynamic _apiDataSource;

  InviteNotifier(this._apiDataSource) : super(InviteState()) {
    loadInviteLinks();
  }

  Future<void> loadInviteLinks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final links = await _apiDataSource.getMyInviteLinks();
      state = state.copyWith(
        inviteLinks: links,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<InviteLink?> createInviteLink() async {
    state = state.copyWith(isCreating: true, error: null);
    try {
      final newLink = await _apiDataSource.createInviteLink();
      state = state.copyWith(
        inviteLinks: [newLink, ...state.inviteLinks],
        isCreating: false,
      );
      return newLink;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<void> refresh() async {
    await loadInviteLinks();
  }
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chat_model.dart';
import 'auth_provider.dart';

final chatsProvider = StateNotifierProvider<ChatsNotifier, ChatsState>((ref) {
  return ChatsNotifier(ref.read(chatRepositoryProvider));
});

class ChatsState {
  final List<Chat> chats;
  final bool isLoading;
  final String? error;

  ChatsState({
    this.chats = const [],
    this.isLoading = false,
    this.error,
  });

  ChatsState copyWith({
    List<Chat>? chats,
    bool? isLoading,
    String? error,
  }) {
    return ChatsState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<Chat> get groupChats => chats.where((c) => c.type == ChatType.group).toList();
  List<Chat> get privateChats => chats.where((c) => c.type == ChatType.private).toList();
}

class ChatsNotifier extends StateNotifier<ChatsState> {
  final dynamic _chatRepository;

  ChatsNotifier(this._chatRepository) : super(ChatsState()) {
    // НЕ загружаем чаты автоматически - они будут загружены MainScreen
    // после того, как токен будет восстановлен
  }

  Future<void> loadChats({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final chats = await _chatRepository.getChats(forceRefresh: forceRefresh);
      
      state = state.copyWith(
        chats: chats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<Chat?> createChat({
    String? title,
    required List<String> participantIds,
  }) async {
    try {
      final chat = await _chatRepository.createChat(
        title: title ?? '',
        participantIds: participantIds,
      );
      await loadChats(forceRefresh: true);
      return chat;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}



import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_profile_model.dart';
import '../models/invite_link_model.dart';
import '../../core/constants/api_constants.dart';

class ApiDataSource {
  final Dio _dio;

  ApiDataSource() : _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Auth
  Future<AuthResponse> register({
    required String phoneNumber,
    required String displayName,
    required String password,
    required String inviteCode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'phoneNumber': phoneNumber,
          'displayName': displayName,
          'password': password,
          'inviteCode': inviteCode,
        },
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<AuthResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'phoneNumber': phoneNumber,
          'password': password,
        },
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Chats
  Future<List<Chat>> getChats() async {
    try {
      final response = await _dio.get(ApiConstants.chats);
      return (response.data as List)
          .map((json) => Chat.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get chats: $e');
    }
  }

  Future<Chat> getChat(String chatId) async {
    try {
      final response = await _dio.get('${ApiConstants.chats}/$chatId');
      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get chat: $e');
    }
  }

  Future<Chat> createChat({
    required String title,
    required List<String> participantIds,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.chats,
        data: {
          'title': title,
          'participantIds': participantIds,
        },
      );
      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create chat: $e');
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _dio.delete('${ApiConstants.chats}/$chatId');
    } catch (e) {
      throw Exception('Failed to delete chat: $e');
    }
  }

  // Messages
  Future<List<Message>> getMessages({
    required String chatId,
    int skip = 0,
    int take = 50,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.messages}/$chatId',
        queryParameters: {
          'skip': skip,
          'take': take,
        },
      );
      return (response.data as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  Future<Message> sendMessage({
    required String chatId,
    required MessageType type,
    String? content,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.messages,
        data: {
          'chatId': chatId,
          'type': type.index,
          'content': content,
        },
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<Message> sendAudioMessage({
    required String chatId,
    required String audioPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'chatId': chatId,
        'audioFile': await MultipartFile.fromFile(audioPath),
      });

      final response = await _dio.post(
        ApiConstants.audioMessages,
        data: formData,
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send audio message: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _dio.delete('${ApiConstants.messages}/$messageId');
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<void> batchMarkAsRead(List<String> messageIds) async {
    try {
      await _dio.post(
        '${ApiConstants.messages}/mark-read',
        data: messageIds,
      );
    } catch (e) {
      throw Exception('Failed to batch mark as read: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStatusUpdates({
    required String chatId,
    DateTime? since,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.messages}/$chatId/status-updates',
        queryParameters: since != null ? {'since': since.toIso8601String()} : null,
      );
      return (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      throw Exception('Failed to get status updates: $e');
    }
  }

  /// Get message updates since a specific timestamp (for incremental sync)
  Future<List<Message>> getMessageUpdates({
    required String chatId,
    required DateTime since,
    int take = 100,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.messages}/$chatId/updates',
        queryParameters: {
          'since': since.toIso8601String(),
          'take': take,
        },
      );
      return (response.data as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get message updates: $e');
    }
  }

  /// Get messages with cursor-based pagination (more efficient than offset-based)
  Future<List<Message>> getMessagesWithCursor({
    required String chatId,
    String? cursor,
    int take = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{'take': take};
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }
      
      final response = await _dio.get(
        '${ApiConstants.messages}/$chatId/cursor',
        queryParameters: queryParams,
      );
      return (response.data as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get messages with cursor: $e');
    }
  }

  // Users & Profile
  Future<UserProfile> getUserProfile() async {
    try {
      final response = await _dio.get('/users/me');
      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  Future<List<UserProfile>> getUsers() async {
    try {
      final response = await _dio.get('/users');
      return (response.data as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  // Invite Links
  Future<InviteLink> createInviteLink() async {
    try {
      final response = await _dio.post('/users/invite-link');
      return InviteLink.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create invite link: $e');
    }
  }

  Future<List<InviteLink>> getMyInviteLinks() async {
    try {
      final response = await _dio.get('/users/my-invite-links');
      return (response.data as List)
          .map((json) => InviteLink.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get invite links: $e');
    }
  }
}



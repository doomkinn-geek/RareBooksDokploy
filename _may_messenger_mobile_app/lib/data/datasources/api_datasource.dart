import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/message_receipts_model.dart';
import '../models/user_profile_model.dart';
import '../models/invite_link_model.dart';
import '../models/participant_model.dart';
import '../models/poll_model.dart';
import '../../core/constants/api_constants.dart';

class ApiDataSource {
  final Dio _dio;

  ApiDataSource() : _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Add getter for direct dio access
  Dio get dio => _dio;

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
      // Rethrow to preserve DioException for proper error handling
      rethrow;
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
      // Rethrow to preserve DioException for proper error handling
      rethrow;
    }
  }

  // Chats
  Future<List<Chat>> getChats() async {
    try {
      final response = await _dio.get(ApiConstants.chats);
      final List<Chat> chats = (response.data as List)
          .map((json) => Chat.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<Chat>();
      return chats;
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

  Future<Chat> createOrGetDirectChat(String targetUserId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.chats}/create-or-get',
        data: {'targetUserId': targetUserId},
      );
      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create or get direct chat: $e');
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
      final List<Message> messages = (response.data as List)
          .map((json) {
            final message = Message.fromJson(json as Map<String, dynamic>);
            // Log poll data for debugging
            if (message.type == MessageType.poll) {
              print('[API] Poll message: id=${message.id}, pollData=${json['poll'] != null ? 'present' : 'null'}, raw poll: ${json['poll']}');
            }
            return message;
          })
          .toList()
          .cast<Message>();
      return messages;
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  Future<Message> sendMessage({
    required String chatId,
    required MessageType type,
    String? content,
    String? clientMessageId,
    String? replyToMessageId,
    bool isEncrypted = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.messages,
        data: {
          'chatId': chatId,
          'type': type.index,
          'content': content,
          'clientMessageId': clientMessageId,
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
          'isEncrypted': isEncrypted,
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
    String? clientMessageId,
    String? replyToMessageId,
    void Function(double progress)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'chatId': chatId,
        'audioFile': await MultipartFile.fromFile(audioPath),
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      });

      final response = await _dio.post(
        ApiConstants.audioMessages,
        data: formData,
        onSendProgress: onSendProgress != null 
            ? (count, total) => onSendProgress(total > 0 ? count / total : 0)
            : null,
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send audio message: $e');
    }
  }

  Future<Message> sendImageMessage({
    required String chatId,
    required String imagePath,
    String? clientMessageId,
    String? replyToMessageId,
    void Function(double progress)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'chatId': chatId,
        'imageFile': await MultipartFile.fromFile(imagePath),
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      });

      final response = await _dio.post(
        ApiConstants.imageMessages,
        data: formData,
        onSendProgress: onSendProgress != null 
            ? (count, total) => onSendProgress(total > 0 ? count / total : 0)
            : null,
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send image message: $e');
    }
  }

  Future<Message> sendFileMessage({
    required String chatId,
    required String filePath,
    required String fileName,
    String? clientMessageId,
    String? replyToMessageId,
    void Function(double progress)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'chatId': chatId,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      });

      final response = await _dio.post(
        ApiConstants.fileMessages,
        data: formData,
        onSendProgress: onSendProgress != null 
            ? (count, total) => onSendProgress(total > 0 ? count / total : 0)
            : null,
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send file message: $e');
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
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );
    } catch (e) {
      throw Exception('Failed to batch mark as read: $e');
    }
  }

  /// Get unsynced messages since a specific timestamp (for incremental sync)
  Future<List<Message>> getUnsyncedMessages({
    required DateTime since,
    int take = 100,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.messages}/unsynced',
        queryParameters: {
          'since': since.toIso8601String(),
          'take': take,
        },
      );
      final List<Message> messages = (response.data as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<Message>();
      return messages;
    } catch (e) {
      print('[API] Failed to get unsynced messages: $e');
      throw Exception('Failed to get unsynced messages: $e');
    }
  }

  /// Get a specific message by ID (for recovery after push notification)
  Future<Message> getMessageById(String messageId) async {
    try {
      final response = await _dio.get('${ApiConstants.messages}/by-id/$messageId');
      return Message.fromJson(response.data);
    } catch (e) {
      print('[API] Failed to get message by ID: $e');
      throw Exception('Failed to get message by ID: $e');
    }
  }

  Future<void> markAudioAsPlayed(String messageId) async {
    try {
      await _dio.post(
        '${ApiConstants.messages}/$messageId/played',
      );
    } catch (e) {
      throw Exception('Failed to mark audio as played: $e');
    }
  }
  
  /// Get delivery receipts for a message (who delivered, who read, when)
  /// Used for group chats to show message status per participant (like WhatsApp)
  Future<MessageReceiptsResponse> getMessageReceipts(String messageId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.messages}/$messageId/receipts',
      );
      return MessageReceiptsResponse.fromJson(response.data);
    } catch (e) {
      print('[API] Failed to get message receipts: $e');
      throw Exception('Failed to get message receipts: $e');
    }
  }

  /// Get statuses for multiple messages (polling fallback)
  Future<Map<String, MessageStatus>> getMessageStatuses(List<String> messageIds) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.messages}/statuses',
        data: messageIds,
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );
      
      final Map<String, MessageStatus> result = {};
      final data = response.data as List<dynamic>;
      
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          // Handle both camelCase (messageId) and PascalCase (MessageId) from server
          final messageId = (item['messageId'] ?? item['MessageId']) as String?;
          final statusIndex = (item['status'] ?? item['Status']) as int?;
          if (messageId != null && statusIndex != null && statusIndex < MessageStatus.values.length) {
            result[messageId] = MessageStatus.values[statusIndex];
          }
        }
      }
      
      return result;
    } catch (e) {
      print('[API] Failed to get message statuses: $e');
      throw Exception('Failed to get message statuses: $e');
    }
  }

  /// Confirm delivery for multiple messages (after push notification)
  Future<void> batchConfirmDelivery(List<String> messageIds) async {
    try {
      await _dio.post(
        '${ApiConstants.messages}/confirm-delivery',
        data: messageIds,
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );
    } catch (e) {
      print('[API] Failed to confirm delivery: $e');
      throw Exception('Failed to confirm delivery: $e');
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
      final List<Message> messages = (response.data as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<Message>();
      return messages;
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
      final List<Message> messages = (response.data as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<Message>();
      return messages;
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

  Future<UserProfile> updateProfile({
    String? displayName,
    String? bio,
    String? status,
  }) async {
    try {
      final response = await _dio.put(
        '/users/me',
        data: {
          if (displayName != null) 'displayName': displayName,
          if (bio != null) 'bio': bio,
          if (status != null) 'status': status,
        },
      );
      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<UserProfile> uploadAvatar(String filePath) async {
    try {
      print('[API] Uploading avatar from: $filePath');
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      
      final response = await _dio.post(
        '/users/me/avatar',
        data: formData,
      );
      
      print('[API] Upload response: ${response.data}');
      print('[API] Avatar URL in response: ${response.data['avatar']}');
      
      final profile = UserProfile.fromJson(response.data);
      print('[API] Parsed profile avatar: ${profile.avatar}');
      
      return profile;
    } catch (e) {
      print('[API] Avatar upload error: $e');
      throw Exception('Failed to upload avatar: $e');
    }
  }

  Future<UserProfile> deleteAvatar() async {
    try {
      final response = await _dio.delete('/users/me/avatar');
      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to delete avatar: $e');
    }
  }

  Future<UserProfile> getUserById(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  Future<List<UserProfile>> getUsers() async {
    try {
      final response = await _dio.get('/users');
      final List<UserProfile> users = (response.data as List)
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<UserProfile>();
      return users;
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
      final List<InviteLink> inviteLinks = (response.data as List)
          .map((json) => InviteLink.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<InviteLink>();
      return inviteLinks;
    } catch (e) {
      throw Exception('Failed to get invite links: $e');
    }
  }

  /// Validate an invite code before registration
  Future<InviteCodeValidation> validateInviteCode(String code) async {
    try {
      final response = await _dio.get('/auth/validate-invite/$code');
      return InviteCodeValidation.fromJson(response.data);
    } catch (e) {
      return InviteCodeValidation(
        isValid: false,
        message: 'Не удалось проверить код приглашения',
      );
    }
  }
  
  // Group Participants Management
  
  /// Get all participants of a chat
  Future<List<Participant>> getParticipants(String chatId) async {
    try {
      final response = await _dio.get('${ApiConstants.chats}/$chatId/participants');
      final List<Participant> participants = (response.data as List)
          .map((json) => Participant.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<Participant>();
      return participants;
    } catch (e) {
      throw Exception('Failed to get participants: $e');
    }
  }
  
  /// Add participants to a group chat
  Future<void> addParticipants(String chatId, List<String> userIds) async {
    try {
      await _dio.post(
        '${ApiConstants.chats}/$chatId/participants',
        data: {'userIds': userIds},
      );
    } catch (e) {
      throw Exception('Failed to add participants: $e');
    }
  }
  
  /// Remove a participant from a group chat
  Future<void> removeParticipant(String chatId, String userId) async {
    try {
      await _dio.delete('${ApiConstants.chats}/$chatId/participants/$userId');
    } catch (e) {
      throw Exception('Failed to remove participant: $e');
    }
  }
  
  /// Promote a participant to admin
  Future<void> promoteToAdmin(String chatId, String userId) async {
    try {
      await _dio.post('${ApiConstants.chats}/$chatId/admins/$userId');
    } catch (e) {
      throw Exception('Failed to promote to admin: $e');
    }
  }
  
  /// Demote an admin to regular participant
  Future<void> demoteAdmin(String chatId, String userId) async {
    try {
      await _dio.delete('${ApiConstants.chats}/$chatId/admins/$userId');
    } catch (e) {
      throw Exception('Failed to demote admin: $e');
    }
  }
  
  /// Leave a group chat
  Future<void> leaveChat(String chatId) async {
    try {
      await _dio.post('${ApiConstants.chats}/$chatId/leave');
    } catch (e) {
      throw Exception('Failed to leave chat: $e');
    }
  }
  
  // Group Avatar Management
  
  /// Upload group avatar
  Future<Chat> uploadGroupAvatar(String chatId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      
      final response = await _dio.post(
        '${ApiConstants.chats}/$chatId/avatar',
        data: formData,
      );
      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to upload group avatar: $e');
    }
  }
  
  /// Delete group avatar
  Future<Chat> deleteGroupAvatar(String chatId) async {
    try {
      final response = await _dio.delete('${ApiConstants.chats}/$chatId/avatar');
      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to delete group avatar: $e');
    }
  }
  
  /// Update group title
  Future<Chat> updateGroupTitle(String chatId, String title) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.chats}/$chatId/title',
        data: {'title': title},
      );
      return Chat.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update group title: $e');
    }
  }
  
  // Message Management (Edit, Forward, Reply)
  
  /// Edit a text message
  Future<Message> editMessage(String messageId, String newContent) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.messages}/$messageId',
        data: {'content': newContent},
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }
  
  /// Forward a message to another chat
  Future<Message> forwardMessage({
    required String originalMessageId,
    required String targetChatId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.messages}/forward',
        data: {
          'originalMessageId': originalMessageId,
          'targetChatId': targetChatId,
        },
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to forward message: $e');
    }
  }
  
  /// Send a message with reply
  Future<Message> sendMessageWithReply({
    required String chatId,
    required String content,
    required String replyToMessageId,
    String? clientMessageId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.messages,
        data: {
          'chatId': chatId,
          'type': MessageType.text.index,
          'content': content,
          'replyToMessageId': replyToMessageId,
          'clientMessageId': clientMessageId,
        },
      );
      return Message.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send message with reply: $e');
    }
  }
  
  // ==================== Presence Management ====================
  
  /// Set current user as online (call when app is in foreground)
  Future<void> goOnline() async {
    try {
      await _dio.post('/users/go-online');
      print('[API] User marked as online');
    } catch (e) {
      print('[API] Failed to mark user as online: $e');
      // Don't throw - this is not critical
    }
  }
  
  /// Set current user as offline (call when app goes to background)
  Future<void> goOffline() async {
    try {
      await _dio.post('/users/go-offline');
      print('[API] User marked as offline');
    } catch (e) {
      print('[API] Failed to mark user as offline: $e');
      // Don't throw - this is not critical
    }
  }
  
  // ==================== Encryption API ====================
  
  /// Update the current user's public key on the server
  Future<void> updatePublicKey(String publicKeyBase64) async {
    try {
      await _dio.put(
        '${ApiConstants.users}/public-key',
        data: {
          'publicKey': publicKeyBase64,
        },
      );
      print('[API] Public key updated successfully');
    } catch (e) {
      print('[API] Failed to update public key: $e');
      throw Exception('Failed to update public key: $e');
    }
  }
  
  /// Get public key of a specific user
  Future<String?> getUserPublicKey(String userId) async {
    try {
      final response = await _dio.get('${ApiConstants.users}/$userId/public-key');
      return response.data['publicKey'] as String?;
    } catch (e) {
      print('[API] Failed to get user public key: $e');
      return null;
    }
  }
  
  /// Get public keys for multiple users
  Future<Map<String, String?>> getPublicKeys(List<String> userIds) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.users}/public-keys',
        data: userIds,
      );
      
      final result = <String, String?>{};
      for (final item in response.data as List) {
        final userId = item['userId'] as String;
        final publicKey = item['publicKey'] as String?;
        result[userId] = publicKey;
      }
      return result;
    } catch (e) {
      print('[API] Failed to get public keys: $e');
      return {};
    }
  }
  
  /// Distribute encrypted group keys to chat participants
  Future<void> distributeGroupKeys(String chatId, List<Map<String, String>> participantKeys) async {
    try {
      await _dio.post(
        '${ApiConstants.chats}/$chatId/distribute-keys',
        data: {
          'chatId': chatId,
          'participantKeys': participantKeys,
        },
      );
      print('[API] Group keys distributed successfully');
    } catch (e) {
      print('[API] Failed to distribute group keys: $e');
      throw Exception('Failed to distribute group keys: $e');
    }
  }
  
  // ====================== POLLS ======================
  
  /// Create a new poll in a group chat
  Future<Message> createPoll(CreatePollRequest request) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.apiUrl}/polls',
        data: request.toJson(),
      );
      return Message.fromJson(response.data);
    } catch (e) {
      print('[API] Failed to create poll: $e');
      throw Exception('Failed to create poll: $e');
    }
  }
  
  /// Vote on a poll
  Future<Poll> votePoll(String pollId, List<String> optionIds) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.apiUrl}/polls/vote',
        data: {
          'pollId': pollId,
          'optionIds': optionIds,
        },
      );
      return Poll.fromJson(response.data);
    } catch (e) {
      print('[API] Failed to vote on poll: $e');
      throw Exception('Failed to vote on poll: $e');
    }
  }
  
  /// Retract votes from a poll
  Future<Poll> retractPollVote(String pollId, List<String> optionIds) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.apiUrl}/polls/retract',
        data: {
          'pollId': pollId,
          'optionIds': optionIds,
        },
      );
      return Poll.fromJson(response.data);
    } catch (e) {
      print('[API] Failed to retract poll vote: $e');
      throw Exception('Failed to retract poll vote: $e');
    }
  }
  
  /// Close a poll (creator only)
  Future<Poll> closePoll(String pollId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.apiUrl}/polls/$pollId/close',
      );
      return Poll.fromJson(response.data);
    } catch (e) {
      print('[API] Failed to close poll: $e');
      throw Exception('Failed to close poll: $e');
    }
  }
  
  /// Get voters for a poll (non-anonymous polls only)
  Future<List<PollOption>> getPollVoters(String pollId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.apiUrl}/polls/$pollId/voters',
      );
      return (response.data as List)
          .map((o) => PollOption.fromJson(o))
          .toList();
    } catch (e) {
      print('[API] Failed to get poll voters: $e');
      throw Exception('Failed to get poll voters: $e');
    }
  }
}



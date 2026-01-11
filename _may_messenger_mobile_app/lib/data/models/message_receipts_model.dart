/// Model for message receipts response (delivery/read status per participant)
class MessageReceiptsResponse {
  final String messageId;
  final String chatId;
  final bool isGroupChat;
  final int totalParticipants;
  final int deliveredCount;
  final int readCount;
  final int playedCount;
  final List<ParticipantReceipt> receipts;

  MessageReceiptsResponse({
    required this.messageId,
    required this.chatId,
    required this.isGroupChat,
    required this.totalParticipants,
    required this.deliveredCount,
    required this.readCount,
    required this.playedCount,
    required this.receipts,
  });

  factory MessageReceiptsResponse.fromJson(Map<String, dynamic> json) {
    return MessageReceiptsResponse(
      messageId: json['messageId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      isGroupChat: json['isGroupChat'] ?? false,
      totalParticipants: json['totalParticipants'] ?? 0,
      deliveredCount: json['deliveredCount'] ?? 0,
      readCount: json['readCount'] ?? 0,
      playedCount: json['playedCount'] ?? 0,
      receipts: (json['receipts'] as List<dynamic>?)
          ?.map((e) => ParticipantReceipt.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Model for individual participant's receipt status
class ParticipantReceipt {
  final String oderId;
  final String userName;
  final String? userAvatar;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? playedAt;

  ParticipantReceipt({
    required this.oderId,
    required this.userName,
    this.userAvatar,
    this.deliveredAt,
    this.readAt,
    this.playedAt,
  });

  factory ParticipantReceipt.fromJson(Map<String, dynamic> json) {
    return ParticipantReceipt(
      oderId: json['userId']?.toString() ?? '',
      userName: json['userName'] ?? 'Unknown',
      userAvatar: json['userAvatar'],
      deliveredAt: json['deliveredAt'] != null 
          ? DateTime.parse(json['deliveredAt']) 
          : null,
      readAt: json['readAt'] != null 
          ? DateTime.parse(json['readAt']) 
          : null,
      playedAt: json['playedAt'] != null 
          ? DateTime.parse(json['playedAt']) 
          : null,
    );
  }
  
  /// Get the current status as a display string
  String get statusText {
    if (playedAt != null) return 'Прослушано';
    if (readAt != null) return 'Прочитано';
    if (deliveredAt != null) return 'Доставлено';
    return 'Отправлено';
  }
  
  /// Get the timestamp for the most recent status
  DateTime? get latestStatusTime => playedAt ?? readAt ?? deliveredAt;
}


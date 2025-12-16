import 'message_model.dart';

enum ChatType {
  private,
  group,
}

class Chat {
  final String id;
  final ChatType type;
  final String title;
  final String? avatar;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final String? otherParticipantId; // For private chats

  Chat({
    required this.id,
    required this.type,
    required this.title,
    this.avatar,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    this.otherParticipantId,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      type: ChatType.values[json['type']],
      title: json['title'],
      avatar: json['avatar'],
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      otherParticipantId: json['otherParticipantId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'title': title,
      'avatar': avatar,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'otherParticipantId': otherParticipantId,
    };
  }
}



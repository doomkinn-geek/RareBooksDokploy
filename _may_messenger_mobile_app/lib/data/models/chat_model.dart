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
  
  // Online status for other participant (private chats only)
  final bool? otherParticipantIsOnline;
  final DateTime? otherParticipantLastSeenAt;
  
  // Avatar of other participant (private chats only)
  final String? otherParticipantAvatar;

  Chat({
    required this.id,
    required this.type,
    required this.title,
    this.avatar,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
    this.otherParticipantId,
    this.otherParticipantIsOnline,
    this.otherParticipantLastSeenAt,
    this.otherParticipantAvatar,
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
      otherParticipantIsOnline: json['otherParticipantIsOnline'],
      otherParticipantLastSeenAt: json['otherParticipantLastSeenAt'] != null
          ? DateTime.parse(json['otherParticipantLastSeenAt'])
          : null,
      otherParticipantAvatar: json['otherParticipantAvatar'],
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
      'otherParticipantIsOnline': otherParticipantIsOnline,
      'otherParticipantLastSeenAt': otherParticipantLastSeenAt?.toIso8601String(),
      'otherParticipantAvatar': otherParticipantAvatar,
    };
  }
  
  /// Get the effective avatar URL for display
  /// For private chats, uses other participant's avatar; for group chats, uses chat avatar
  String? get displayAvatar {
    if (type == ChatType.private) {
      return otherParticipantAvatar;
    }
    return avatar;
  }
  
  /// Get formatted status text for private chats
  String get statusText {
    if (type != ChatType.private) return '';
    
    if (otherParticipantIsOnline == true) return 'онлайн';
    if (otherParticipantLastSeenAt != null) {
      return 'был(а) ${_formatLastSeen(otherParticipantLastSeenAt!)}';
    }
    return '';
  }
  
  /// Format last seen time
  static String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${_pluralizeMinutes(minutes)} назад';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${_pluralizeHours(hours)} назад';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${_pluralizeDays(days)} назад';
    } else {
      // Format as date
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }
  
  static String _pluralizeMinutes(int minutes) {
    if (minutes % 10 == 1 && minutes % 100 != 11) return 'минуту';
    if (minutes % 10 >= 2 && minutes % 10 <= 4 && (minutes % 100 < 10 || minutes % 100 >= 20)) return 'минуты';
    return 'минут';
  }
  
  static String _pluralizeHours(int hours) {
    if (hours % 10 == 1 && hours % 100 != 11) return 'час';
    if (hours % 10 >= 2 && hours % 10 <= 4 && (hours % 100 < 10 || hours % 100 >= 20)) return 'часа';
    return 'часов';
  }
  
  static String _pluralizeDays(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if (days % 10 >= 2 && days % 10 <= 4 && (days % 100 < 10 || days % 100 >= 20)) return 'дня';
    return 'дней';
  }
  
  /// Copy with method for updating fields
  Chat copyWith({
    String? id,
    ChatType? type,
    String? title,
    String? avatar,
    Message? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    String? otherParticipantId,
    bool? otherParticipantIsOnline,
    DateTime? otherParticipantLastSeenAt,
    String? otherParticipantAvatar,
  }) {
    return Chat(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      avatar: avatar ?? this.avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      otherParticipantId: otherParticipantId ?? this.otherParticipantId,
      otherParticipantIsOnline: otherParticipantIsOnline ?? this.otherParticipantIsOnline,
      otherParticipantLastSeenAt: otherParticipantLastSeenAt ?? this.otherParticipantLastSeenAt,
      otherParticipantAvatar: otherParticipantAvatar ?? this.otherParticipantAvatar,
    );
  }
}



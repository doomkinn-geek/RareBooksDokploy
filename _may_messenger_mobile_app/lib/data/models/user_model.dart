enum UserRole {
  user,
  admin,
}

class User {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String? avatar;
  final UserRole role;
  final bool isOnline;
  final DateTime? lastSeenAt;

  User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.avatar,
    required this.role,
    this.isOnline = false,
    this.lastSeenAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      displayName: json['displayName'],
      avatar: json['avatar'],
      role: UserRole.values[json['role']],
      isOnline: json['isOnline'] ?? false,
      lastSeenAt: json['lastSeenAt'] != null 
          ? DateTime.parse(json['lastSeenAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'avatar': avatar,
      'role': role.index,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }
  
  /// Get formatted online status text
  String get statusText {
    if (isOnline) return 'онлайн';
    if (lastSeenAt != null) {
      return 'был(а) ${_formatLastSeen(lastSeenAt!)}';
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
  User copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? avatar,
    UserRole? role,
    bool? isOnline,
    DateTime? lastSeenAt,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}



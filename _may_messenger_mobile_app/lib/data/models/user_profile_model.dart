import '../../domain/entities/user_role.dart';

class UserProfile {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String? avatar;
  final UserRole role;
  final String? bio;
  final String? status;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.avatar,
    required this.role,
    this.bio,
    this.status,
    this.isOnline = false,
    this.lastSeenAt,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      displayName: json['displayName'],
      avatar: json['avatar'],
      role: UserRole.values[json['role']],
      bio: json['bio'],
      status: json['status'],
      isOnline: json['isOnline'] ?? false,
      lastSeenAt: json['lastSeenAt'] != null 
          ? DateTime.parse(json['lastSeenAt']) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
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
      'bio': bio,
      'status': status,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == UserRole.admin;

  /// Format last seen time for display
  String get lastSeenText {
    if (isOnline) return 'онлайн';
    if (lastSeenAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeenAt!);
    
    if (difference.inSeconds < 60) {
      return 'был(а) только что';
    } else if (difference.inMinutes < 60) {
      return 'был(а) ${difference.inMinutes} мин. назад';
    } else if (difference.inHours < 24) {
      return 'был(а) ${difference.inHours} ч. назад';
    } else {
      return 'был(а) ${difference.inDays} дн. назад';
    }
  }

  UserProfile copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? avatar,
    UserRole? role,
    String? bio,
    String? status,
    bool? isOnline,
    DateTime? lastSeenAt,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


import '../../domain/entities/user_role.dart';

class UserProfile {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String? avatar;
  final UserRole role;

  UserProfile({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.avatar,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      displayName: json['displayName'],
      avatar: json['avatar'],
      role: UserRole.values[json['role']],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'avatar': avatar,
      'role': role.index,
    };
  }

  bool get isAdmin => role == UserRole.admin;

  UserProfile copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? avatar,
    UserRole? role,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
    );
  }
}


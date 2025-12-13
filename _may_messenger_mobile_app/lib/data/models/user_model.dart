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

  User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.avatar,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
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
}



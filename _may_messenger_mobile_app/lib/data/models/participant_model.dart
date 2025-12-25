/// Role of a participant in a group chat
enum ParticipantRole {
  member,  // Regular member
  admin,   // Can add/remove participants
  owner,   // Creator - can also manage admins and delete any message
}

/// Model representing a participant in a chat
class Participant {
  final String id;
  final String displayName;
  final bool isOwner;
  final bool isAdmin;
  final DateTime joinedAt;
  
  Participant({
    required this.id,
    required this.displayName,
    required this.isOwner,
    required this.isAdmin,
    required this.joinedAt,
  });
  
  /// Get the role of this participant
  ParticipantRole get role {
    if (isOwner) return ParticipantRole.owner;
    if (isAdmin) return ParticipantRole.admin;
    return ParticipantRole.member;
  }
  
  /// Get localized role name
  String get roleDisplayName {
    switch (role) {
      case ParticipantRole.owner:
        return 'Создатель';
      case ParticipantRole.admin:
        return 'Администратор';
      case ParticipantRole.member:
        return 'Участник';
    }
  }
  
  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['userId'] as String,
      displayName: json['displayName'] as String,
      isOwner: json['isOwner'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'displayName': displayName,
      'isOwner': isOwner,
      'isAdmin': isAdmin,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}


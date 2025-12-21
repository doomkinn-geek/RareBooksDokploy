class ContactCache {
  final String userId;
  final String displayName; // from phone book
  final String phoneNumberHash;
  final DateTime cachedAt;

  ContactCache({
    required this.userId,
    required this.displayName,
    required this.phoneNumberHash,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'phoneNumberHash': phoneNumberHash,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  factory ContactCache.fromJson(Map<String, dynamic> json) {
    return ContactCache(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      phoneNumberHash: json['phoneNumberHash'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }
}


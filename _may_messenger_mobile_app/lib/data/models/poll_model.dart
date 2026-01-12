/// Model for poll/vote in group chats
class Poll {
  final String id;
  final String question;
  final bool allowMultipleAnswers;
  final bool isAnonymous;
  final bool isClosed;
  final DateTime? closesAt;
  final int totalVoters;
  final List<PollOption> options;
  final List<String> myVotes; // IDs of options current user voted for

  Poll({
    required this.id,
    required this.question,
    this.allowMultipleAnswers = false,
    this.isAnonymous = false,
    this.isClosed = false,
    this.closesAt,
    this.totalVoters = 0,
    this.options = const [],
    this.myVotes = const [],
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'],
      question: json['question'] ?? '',
      allowMultipleAnswers: json['allowMultipleAnswers'] ?? false,
      isAnonymous: json['isAnonymous'] ?? false,
      isClosed: json['isClosed'] ?? false,
      closesAt: json['closesAt'] != null ? DateTime.parse(json['closesAt']) : null,
      totalVoters: json['totalVoters'] ?? 0,
      options: (json['options'] as List<dynamic>?)
          ?.map((o) => PollOption.fromJson(o))
          .toList() ?? [],
      myVotes: (json['myVotes'] as List<dynamic>?)
          ?.map((v) => v.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'allowMultipleAnswers': allowMultipleAnswers,
      'isAnonymous': isAnonymous,
      'isClosed': isClosed,
      'closesAt': closesAt?.toIso8601String(),
      'totalVoters': totalVoters,
      'options': options.map((o) => o.toJson()).toList(),
      'myVotes': myVotes,
    };
  }

  Poll copyWith({
    String? id,
    String? question,
    bool? allowMultipleAnswers,
    bool? isAnonymous,
    bool? isClosed,
    DateTime? closesAt,
    int? totalVoters,
    List<PollOption>? options,
    List<String>? myVotes,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      allowMultipleAnswers: allowMultipleAnswers ?? this.allowMultipleAnswers,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isClosed: isClosed ?? this.isClosed,
      closesAt: closesAt ?? this.closesAt,
      totalVoters: totalVoters ?? this.totalVoters,
      options: options ?? this.options,
      myVotes: myVotes ?? this.myVotes,
    );
  }
  
  /// Check if current user has voted
  bool get hasVoted => myVotes.isNotEmpty;
}

/// Model for poll option
class PollOption {
  final String id;
  final String text;
  final int order;
  final int voteCount;
  final int percentage;
  final List<Voter>? voters;

  PollOption({
    required this.id,
    required this.text,
    this.order = 0,
    this.voteCount = 0,
    this.percentage = 0,
    this.voters,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'],
      text: json['text'] ?? '',
      order: json['order'] ?? 0,
      voteCount: json['voteCount'] ?? 0,
      percentage: json['percentage'] ?? 0,
      voters: (json['voters'] as List<dynamic>?)
          ?.map((v) => Voter.fromJson(v))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'order': order,
      'voteCount': voteCount,
      'percentage': percentage,
      'voters': voters?.map((v) => v.toJson()).toList(),
    };
  }
}

/// Model for voter info
class Voter {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  Voter({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      userId: json['userId'],
      displayName: json['displayName'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }
}

/// DTO for creating a poll
class CreatePollRequest {
  final String chatId;
  final String question;
  final List<String> options;
  final bool allowMultipleAnswers;
  final bool isAnonymous;
  final int? closesInMinutes;

  CreatePollRequest({
    required this.chatId,
    required this.question,
    required this.options,
    this.allowMultipleAnswers = false,
    this.isAnonymous = false,
    this.closesInMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'question': question,
      'options': options,
      'allowMultipleAnswers': allowMultipleAnswers,
      'isAnonymous': isAnonymous,
      if (closesInMinutes != null) 'closesInMinutes': closesInMinutes,
    };
  }
}


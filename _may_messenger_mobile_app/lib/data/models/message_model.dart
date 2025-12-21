enum MessageType {
  text,
  audio,
  image,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
  played, // For audio messages that have been played
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String? content;
  final String? filePath;
  final String? localAudioPath;
  final String? localImagePath;
  final MessageStatus status;
  final DateTime createdAt;
  final String? localId; // Client-side UUID for tracking before server confirms
  final bool isLocalOnly; // True if message hasn't been synced to server yet

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.content,
    this.filePath,
    this.localAudioPath,
    this.localImagePath,
    required this.status,
    required this.createdAt,
    this.localId,
    this.isLocalOnly = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      type: MessageType.values[json['type']],
      content: json['content'],
      filePath: json['filePath'],
      localAudioPath: json['localAudioPath'],
      localImagePath: json['localImagePath'],
      status: MessageStatus.values[json['status']],
      createdAt: DateTime.parse(json['createdAt']),
      localId: json['localId'],
      isLocalOnly: json['isLocalOnly'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.index,
      'content': content,
      'filePath': filePath,
      'localAudioPath': localAudioPath,
      'localImagePath': localImagePath,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'localId': localId,
      'isLocalOnly': isLocalOnly,
    };
  }

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    MessageType? type,
    String? content,
    String? filePath,
    String? localAudioPath,
    String? localImagePath,
    MessageStatus? status,
    DateTime? createdAt,
    String? localId,
    bool? isLocalOnly,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localImagePath: localImagePath ?? this.localImagePath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      localId: localId ?? this.localId,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }
}



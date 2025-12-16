enum MessageType {
  text,
  audio,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
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
  final MessageStatus status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.content,
    this.filePath,
    this.localAudioPath,
    required this.status,
    required this.createdAt,
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
      status: MessageStatus.values[json['status']],
      createdAt: DateTime.parse(json['createdAt']),
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
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
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
    MessageStatus? status,
    DateTime? createdAt,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}



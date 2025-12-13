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
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}



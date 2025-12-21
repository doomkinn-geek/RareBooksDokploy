import 'message_model.dart';

class MessageSearchResult {
  final String id;
  final String chatId;
  final String chatTitle;
  final String? chatAvatar;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String? content;
  final DateTime createdAt;
  final String? snippet;

  MessageSearchResult({
    required this.id,
    required this.chatId,
    required this.chatTitle,
    this.chatAvatar,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.content,
    required this.createdAt,
    this.snippet,
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    return MessageSearchResult(
      id: json['id'],
      chatId: json['chatId'],
      chatTitle: json['chatTitle'],
      chatAvatar: json['chatAvatar'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      type: MessageType.values[json['type']],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      snippet: json['snippet'],
    );
  }
}


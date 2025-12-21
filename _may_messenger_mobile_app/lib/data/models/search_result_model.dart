class MessageSearchResult {
  final String messageId;
  final String chatId;
  final String chatTitle;
  final String messageContent;
  final String senderName;
  final DateTime createdAt;

  MessageSearchResult({
    required this.messageId,
    required this.chatId,
    required this.chatTitle,
    required this.messageContent,
    required this.senderName,
    required this.createdAt,
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    return MessageSearchResult(
      messageId: json['messageId'],
      chatId: json['chatId'],
      chatTitle: json['chatTitle'],
      messageContent: json['messageContent'],
      senderName: json['senderName'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}


enum MessageType {
  text,
  audio,
  image,
  file,
  poll,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
  played, // For audio messages that have been played
}

/// Simplified model for replied message to avoid circular references
class ReplyMessage {
  final String id;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String? content;
  final String? originalFileName;
  final String? filePath; // Path for image/file preview in quote

  ReplyMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.content,
    this.originalFileName,
    this.filePath,
  });

  factory ReplyMessage.fromJson(Map<String, dynamic> json) {
    return ReplyMessage(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'] ?? 'Unknown',
      type: MessageType.values[json['type']],
      content: json['content'],
      originalFileName: json['originalFileName'],
      filePath: json['filePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.index,
      'content': content,
      'originalFileName': originalFileName,
      'filePath': filePath,
    };
  }
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
  final String? localFilePath; // For downloaded files
  final String? originalFileName; // Original file name for file messages
  final int? fileSize; // File size in bytes
  final MessageStatus status;
  final DateTime createdAt;
  final String? localId; // Client-side UUID for tracking before server confirms
  final bool isLocalOnly; // True if message hasn't been synced to server yet
  final String? clientMessageId; // Server returns this for deduplication
  
  // Reply functionality
  final String? replyToMessageId;
  final ReplyMessage? replyToMessage;
  
  // Forward functionality
  final String? forwardedFromMessageId;
  final String? forwardedFromUserId;
  final String? forwardedFromUserName;
  
  // Edit functionality
  final bool isEdited;
  final DateTime? editedAt;
  
  // Deletion
  final bool isDeleted;
  
  // End-to-end encryption
  final bool isEncrypted;
  
  // Upload progress (0.0 - 1.0) for sending media messages
  final double? uploadProgress;
  
  // Download progress (0.0 - 1.0) for receiving media messages
  final double? downloadProgress;
  
  // Poll data (for MessageType.poll)
  final Map<String, dynamic>? pollData;

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
    this.localFilePath,
    this.originalFileName,
    this.fileSize,
    required this.status,
    required this.createdAt,
    this.localId,
    this.isLocalOnly = false,
    this.clientMessageId,
    this.replyToMessageId,
    this.replyToMessage,
    this.forwardedFromMessageId,
    this.forwardedFromUserId,
    this.forwardedFromUserName,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.isEncrypted = false,
    this.uploadProgress,
    this.downloadProgress,
    this.pollData,
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
      localFilePath: json['localFilePath'],
      originalFileName: json['originalFileName'],
      fileSize: json['fileSize'] != null ? (json['fileSize'] is int ? json['fileSize'] : (json['fileSize'] as num).toInt()) : null,
      status: MessageStatus.values[json['status']],
      createdAt: DateTime.parse(json['createdAt']),
      localId: json['localId'],
      isLocalOnly: json['isLocalOnly'] ?? false,
      clientMessageId: json['clientMessageId'],
      replyToMessageId: json['replyToMessageId'],
      replyToMessage: json['replyToMessage'] != null 
          ? ReplyMessage.fromJson(Map<String, dynamic>.from(json['replyToMessage']))
          : null,
      forwardedFromMessageId: json['forwardedFromMessageId'],
      forwardedFromUserId: json['forwardedFromUserId'],
      forwardedFromUserName: json['forwardedFromUserName'],
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
      isDeleted: json['isDeleted'] ?? false,
      isEncrypted: json['isEncrypted'] ?? false,
      uploadProgress: json['uploadProgress'] != null 
          ? (json['uploadProgress'] as num).toDouble() 
          : null,
      downloadProgress: json['downloadProgress'] != null 
          ? (json['downloadProgress'] as num).toDouble() 
          : null,
      pollData: json['poll'] != null 
          ? Map<String, dynamic>.from(json['poll'])
          : null,
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
      'localFilePath': localFilePath,
      'originalFileName': originalFileName,
      'fileSize': fileSize,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'localId': localId,
      'isLocalOnly': isLocalOnly,
      'clientMessageId': clientMessageId,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage?.toJson(),
      'forwardedFromMessageId': forwardedFromMessageId,
      'forwardedFromUserId': forwardedFromUserId,
      'forwardedFromUserName': forwardedFromUserName,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'isEncrypted': isEncrypted,
      'uploadProgress': uploadProgress,
      'downloadProgress': downloadProgress,
      'poll': pollData,
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
    String? localFilePath,
    String? originalFileName,
    int? fileSize,
    MessageStatus? status,
    DateTime? createdAt,
    String? localId,
    bool? isLocalOnly,
    String? clientMessageId,
    String? replyToMessageId,
    ReplyMessage? replyToMessage,
    String? forwardedFromMessageId,
    String? forwardedFromUserId,
    String? forwardedFromUserName,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    bool? isEncrypted,
    double? uploadProgress,
    double? downloadProgress,
    Map<String, dynamic>? pollData,
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
      localFilePath: localFilePath ?? this.localFilePath,
      originalFileName: originalFileName ?? this.originalFileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      localId: localId ?? this.localId,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      forwardedFromMessageId: forwardedFromMessageId ?? this.forwardedFromMessageId,
      forwardedFromUserId: forwardedFromUserId ?? this.forwardedFromUserId,
      forwardedFromUserName: forwardedFromUserName ?? this.forwardedFromUserName,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      pollData: pollData ?? this.pollData,
    );
  }
  
  /// Get preview text for this message (used in reply/forward previews)
  String getPreviewText() {
    if (isDeleted) return '[Сообщение удалено]';
    
    switch (type) {
      case MessageType.text:
        return content ?? '';
      case MessageType.audio:
        return '[Голосовое сообщение]';
      case MessageType.image:
        return '[Изображение]';
      case MessageType.file:
        return '[Файл: ${originalFileName ?? "файл"}]';
      case MessageType.poll:
        final question = pollData?['question'] ?? 'Голосование';
        return '📊 $question';
    }
  }
}

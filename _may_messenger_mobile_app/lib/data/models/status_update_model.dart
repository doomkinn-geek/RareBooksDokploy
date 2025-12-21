import '../models/message_model.dart';

/// Represents a pending status update that needs to be sent to the server
class StatusUpdate {
  final String id; // Unique ID for this status update
  final String messageId;
  final MessageStatus status;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastRetryAt;
  final String? error;

  StatusUpdate({
    required this.id,
    required this.messageId,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
    this.lastRetryAt,
    this.error,
  });

  StatusUpdate copyWith({
    String? id,
    String? messageId,
    MessageStatus? status,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastRetryAt,
    String? error,
  }) {
    return StatusUpdate(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastRetryAt': lastRetryAt?.toIso8601String(),
      'error': error,
    };
  }

  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      id: json['id'],
      messageId: json['messageId'],
      status: MessageStatus.values[json['status']],
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      lastRetryAt: json['lastRetryAt'] != null 
          ? DateTime.parse(json['lastRetryAt']) 
          : null,
      error: json['error'],
    );
  }
}


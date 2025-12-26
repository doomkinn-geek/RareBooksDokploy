import 'package:json_annotation/json_annotation.dart';

part 'notification.g.dart';

/// Notification preference model
@JsonSerializable()
class NotificationPreference {
  final int id;
  final int userId;
  final String? searchQuery;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final String deliveryMethod; // 'email', 'telegram', 'push'
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastNotificationSent;
  
  NotificationPreference({
    required this.id,
    required this.userId,
    this.searchQuery,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    required this.deliveryMethod,
    this.isActive = true,
    this.createdAt,
    this.lastNotificationSent,
  });
  
  factory NotificationPreference.fromJson(Map<String, dynamic> json) => 
      _$NotificationPreferenceFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationPreferenceToJson(this);
}

/// Create/Update notification preference request
@JsonSerializable()
class NotificationPreferenceRequest {
  final String? searchQuery;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final String deliveryMethod;
  final bool isActive;
  
  NotificationPreferenceRequest({
    this.searchQuery,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    required this.deliveryMethod,
    this.isActive = true,
  });
  
  factory NotificationPreferenceRequest.fromJson(Map<String, dynamic> json) => 
      _$NotificationPreferenceRequestFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationPreferenceRequestToJson(this);
}

/// Notification history item
@JsonSerializable()
class NotificationHistoryItem {
  final int id;
  final int userId;
  final String? title;
  final String? message;
  final String deliveryMethod;
  final bool isRead;
  final DateTime? sentAt;
  final int? relatedBookId;
  
  NotificationHistoryItem({
    required this.id,
    required this.userId,
    this.title,
    this.message,
    required this.deliveryMethod,
    this.isRead = false,
    this.sentAt,
    this.relatedBookId,
  });
  
  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) => 
      _$NotificationHistoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationHistoryItemToJson(this);
}

/// Telegram status response
@JsonSerializable()
class TelegramStatus {
  final bool isConnected;
  final String? telegramUserId;
  final String? telegramUsername;
  final DateTime? connectedAt;
  
  TelegramStatus({
    this.isConnected = false,
    this.telegramUserId,
    this.telegramUsername,
    this.connectedAt,
  });
  
  factory TelegramStatus.fromJson(Map<String, dynamic> json) => 
      _$TelegramStatusFromJson(json);
  Map<String, dynamic> toJson() => _$TelegramStatusToJson(this);
}

/// Connect Telegram request
@JsonSerializable()
class ConnectTelegramRequest {
  final String telegramUserId;
  final String? telegramUsername;
  
  ConnectTelegramRequest({
    required this.telegramUserId,
    this.telegramUsername,
  });
  
  factory ConnectTelegramRequest.fromJson(Map<String, dynamic> json) => 
      _$ConnectTelegramRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectTelegramRequestToJson(this);
}


import 'package:json_annotation/json_annotation.dart';

part 'notification.g.dart';

/// Notification preference model - matches backend NotificationPreferenceDto
@JsonSerializable()
class NotificationPreference {
  final int id;
  final int userId;
  final bool isEnabled;
  final String? keywords;
  final String? categoryIds;
  final int notificationFrequencyMinutes;
  final int deliveryMethod; // 1 = Email, 4 = Telegram
  final bool isExactMatch;
  final DateTime? createdAt;
  final DateTime? lastNotificationSent;
  
  NotificationPreference({
    required this.id,
    required this.userId,
    this.isEnabled = true,
    this.keywords,
    this.categoryIds,
    this.notificationFrequencyMinutes = 60,
    this.deliveryMethod = 1,
    this.isExactMatch = false,
    this.createdAt,
    this.lastNotificationSent,
  });
  
  factory NotificationPreference.fromJson(Map<String, dynamic> json) => 
      _$NotificationPreferenceFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationPreferenceToJson(this);
  
  String get deliveryMethodName {
    switch (deliveryMethod) {
      case 4:
        return 'Telegram';
      case 1:
      default:
        return 'Email';
    }
  }
}

/// Create/Update notification preference request
@JsonSerializable()
class NotificationPreferenceRequest {
  final bool isEnabled;
  final String? keywords;
  final String? categoryIds;
  final int notificationFrequencyMinutes;
  final int deliveryMethod;
  final bool isExactMatch;
  
  NotificationPreferenceRequest({
    this.isEnabled = true,
    this.keywords,
    this.categoryIds,
    this.notificationFrequencyMinutes = 60,
    this.deliveryMethod = 1,
    this.isExactMatch = false,
  });
  
  factory NotificationPreferenceRequest.fromJson(Map<String, dynamic> json) => 
      _$NotificationPreferenceRequestFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationPreferenceRequestToJson(this);
}

/// Notification history item - matches backend NotificationHistoryItemDto
@JsonSerializable()
class NotificationHistoryItem {
  final int id;
  final DateTime createdAt;
  final String? bookTitle;
  final double? bookPrice;
  final int deliveryMethod;
  final int status; // 0=Pending, 1=Sending, 2=Sent, 3=Delivered, 4=Read, 5=Failed, 6=Cancelled
  final String? matchedKeywords;
  final int? bookId;
  
  NotificationHistoryItem({
    required this.id,
    required this.createdAt,
    this.bookTitle,
    this.bookPrice,
    required this.deliveryMethod,
    required this.status,
    this.matchedKeywords,
    this.bookId,
  });
  
  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) => 
      _$NotificationHistoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationHistoryItemToJson(this);
  
  String get statusName {
    switch (status) {
      case 0:
        return 'Ожидание';
      case 1:
        return 'Отправка';
      case 2:
        return 'Отправлено';
      case 3:
        return 'Доставлено';
      case 4:
        return 'Прочитано';
      case 5:
        return 'Ошибка';
      case 6:
        return 'Отменено';
      default:
        return 'Неизвестно';
    }
  }
  
  String get deliveryMethodName {
    switch (deliveryMethod) {
      case 4:
        return 'Telegram';
      case 1:
      default:
        return 'Email';
    }
  }
}

/// Telegram status response - matches backend TelegramStatusDto
@JsonSerializable()
class TelegramStatus {
  final bool isConnected;
  final String? telegramId;
  final String? telegramUsername;
  final String? botUsername;
  
  TelegramStatus({
    this.isConnected = false,
    this.telegramId,
    this.telegramUsername,
    this.botUsername,
  });
  
  factory TelegramStatus.fromJson(Map<String, dynamic> json) => 
      _$TelegramStatusFromJson(json);
  Map<String, dynamic> toJson() => _$TelegramStatusToJson(this);
}

/// Connect Telegram request
@JsonSerializable()
class ConnectTelegramRequest {
  final String telegramId;
  final String? telegramUsername;
  
  ConnectTelegramRequest({
    required this.telegramId,
    this.telegramUsername,
  });
  
  factory ConnectTelegramRequest.fromJson(Map<String, dynamic> json) => 
      _$ConnectTelegramRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectTelegramRequestToJson(this);
}

/// Generate Telegram link token response
@JsonSerializable()
class TelegramLinkToken {
  final String token;
  final DateTime expiresAt;
  final List<String> instructions;
  
  TelegramLinkToken({
    required this.token,
    required this.expiresAt,
    required this.instructions,
  });
  
  factory TelegramLinkToken.fromJson(Map<String, dynamic> json) => 
      _$TelegramLinkTokenFromJson(json);
  Map<String, dynamic> toJson() => _$TelegramLinkTokenToJson(this);
}

/// Notification history response with pagination
@JsonSerializable()
class NotificationHistoryResponse {
  final List<NotificationHistoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
  
  NotificationHistoryResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
  
  factory NotificationHistoryResponse.fromJson(Map<String, dynamic> json) => 
      _$NotificationHistoryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationHistoryResponseToJson(this);
}

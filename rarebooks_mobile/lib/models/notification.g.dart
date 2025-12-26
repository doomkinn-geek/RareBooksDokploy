// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationPreference _$NotificationPreferenceFromJson(
  Map<String, dynamic> json,
) => NotificationPreference(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  searchQuery: json['searchQuery'] as String?,
  categoryName: json['categoryName'] as String?,
  minPrice: (json['minPrice'] as num?)?.toDouble(),
  maxPrice: (json['maxPrice'] as num?)?.toDouble(),
  deliveryMethod: json['deliveryMethod'] as String,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  lastNotificationSent: json['lastNotificationSent'] == null
      ? null
      : DateTime.parse(json['lastNotificationSent'] as String),
);

Map<String, dynamic> _$NotificationPreferenceToJson(
  NotificationPreference instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'searchQuery': instance.searchQuery,
  'categoryName': instance.categoryName,
  'minPrice': instance.minPrice,
  'maxPrice': instance.maxPrice,
  'deliveryMethod': instance.deliveryMethod,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt?.toIso8601String(),
  'lastNotificationSent': instance.lastNotificationSent?.toIso8601String(),
};

NotificationPreferenceRequest _$NotificationPreferenceRequestFromJson(
  Map<String, dynamic> json,
) => NotificationPreferenceRequest(
  searchQuery: json['searchQuery'] as String?,
  categoryName: json['categoryName'] as String?,
  minPrice: (json['minPrice'] as num?)?.toDouble(),
  maxPrice: (json['maxPrice'] as num?)?.toDouble(),
  deliveryMethod: json['deliveryMethod'] as String,
  isActive: json['isActive'] as bool? ?? true,
);

Map<String, dynamic> _$NotificationPreferenceRequestToJson(
  NotificationPreferenceRequest instance,
) => <String, dynamic>{
  'searchQuery': instance.searchQuery,
  'categoryName': instance.categoryName,
  'minPrice': instance.minPrice,
  'maxPrice': instance.maxPrice,
  'deliveryMethod': instance.deliveryMethod,
  'isActive': instance.isActive,
};

NotificationHistoryItem _$NotificationHistoryItemFromJson(
  Map<String, dynamic> json,
) => NotificationHistoryItem(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  title: json['title'] as String?,
  message: json['message'] as String?,
  deliveryMethod: json['deliveryMethod'] as String,
  isRead: json['isRead'] as bool? ?? false,
  sentAt: json['sentAt'] == null
      ? null
      : DateTime.parse(json['sentAt'] as String),
  relatedBookId: (json['relatedBookId'] as num?)?.toInt(),
);

Map<String, dynamic> _$NotificationHistoryItemToJson(
  NotificationHistoryItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'title': instance.title,
  'message': instance.message,
  'deliveryMethod': instance.deliveryMethod,
  'isRead': instance.isRead,
  'sentAt': instance.sentAt?.toIso8601String(),
  'relatedBookId': instance.relatedBookId,
};

TelegramStatus _$TelegramStatusFromJson(Map<String, dynamic> json) =>
    TelegramStatus(
      isConnected: json['isConnected'] as bool? ?? false,
      telegramUserId: json['telegramUserId'] as String?,
      telegramUsername: json['telegramUsername'] as String?,
      connectedAt: json['connectedAt'] == null
          ? null
          : DateTime.parse(json['connectedAt'] as String),
    );

Map<String, dynamic> _$TelegramStatusToJson(TelegramStatus instance) =>
    <String, dynamic>{
      'isConnected': instance.isConnected,
      'telegramUserId': instance.telegramUserId,
      'telegramUsername': instance.telegramUsername,
      'connectedAt': instance.connectedAt?.toIso8601String(),
    };

ConnectTelegramRequest _$ConnectTelegramRequestFromJson(
  Map<String, dynamic> json,
) => ConnectTelegramRequest(
  telegramUserId: json['telegramUserId'] as String,
  telegramUsername: json['telegramUsername'] as String?,
);

Map<String, dynamic> _$ConnectTelegramRequestToJson(
  ConnectTelegramRequest instance,
) => <String, dynamic>{
  'telegramUserId': instance.telegramUserId,
  'telegramUsername': instance.telegramUsername,
};

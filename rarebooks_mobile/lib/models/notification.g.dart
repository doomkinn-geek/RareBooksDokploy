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
  isEnabled: json['isEnabled'] as bool? ?? true,
  keywords: json['keywords'] as String?,
  categoryIds: json['categoryIds'] as String?,
  notificationFrequencyMinutes:
      (json['notificationFrequencyMinutes'] as num?)?.toInt() ?? 60,
  deliveryMethod: (json['deliveryMethod'] as num?)?.toInt() ?? 1,
  isExactMatch: json['isExactMatch'] as bool? ?? false,
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
  'isEnabled': instance.isEnabled,
  'keywords': instance.keywords,
  'categoryIds': instance.categoryIds,
  'notificationFrequencyMinutes': instance.notificationFrequencyMinutes,
  'deliveryMethod': instance.deliveryMethod,
  'isExactMatch': instance.isExactMatch,
  'createdAt': instance.createdAt?.toIso8601String(),
  'lastNotificationSent': instance.lastNotificationSent?.toIso8601String(),
};

NotificationPreferenceRequest _$NotificationPreferenceRequestFromJson(
  Map<String, dynamic> json,
) => NotificationPreferenceRequest(
  isEnabled: json['isEnabled'] as bool? ?? true,
  keywords: json['keywords'] as String?,
  categoryIds: json['categoryIds'] as String?,
  notificationFrequencyMinutes:
      (json['notificationFrequencyMinutes'] as num?)?.toInt() ?? 60,
  deliveryMethod: (json['deliveryMethod'] as num?)?.toInt() ?? 1,
  isExactMatch: json['isExactMatch'] as bool? ?? false,
);

Map<String, dynamic> _$NotificationPreferenceRequestToJson(
  NotificationPreferenceRequest instance,
) => <String, dynamic>{
  'isEnabled': instance.isEnabled,
  'keywords': instance.keywords,
  'categoryIds': instance.categoryIds,
  'notificationFrequencyMinutes': instance.notificationFrequencyMinutes,
  'deliveryMethod': instance.deliveryMethod,
  'isExactMatch': instance.isExactMatch,
};

NotificationHistoryItem _$NotificationHistoryItemFromJson(
  Map<String, dynamic> json,
) => NotificationHistoryItem(
  id: (json['id'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  bookTitle: json['bookTitle'] as String?,
  bookPrice: (json['bookPrice'] as num?)?.toDouble(),
  deliveryMethod: (json['deliveryMethod'] as num).toInt(),
  status: (json['status'] as num).toInt(),
  matchedKeywords: json['matchedKeywords'] as String?,
  bookId: (json['bookId'] as num?)?.toInt(),
);

Map<String, dynamic> _$NotificationHistoryItemToJson(
  NotificationHistoryItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt.toIso8601String(),
  'bookTitle': instance.bookTitle,
  'bookPrice': instance.bookPrice,
  'deliveryMethod': instance.deliveryMethod,
  'status': instance.status,
  'matchedKeywords': instance.matchedKeywords,
  'bookId': instance.bookId,
};

TelegramStatus _$TelegramStatusFromJson(Map<String, dynamic> json) =>
    TelegramStatus(
      isConnected: json['isConnected'] as bool? ?? false,
      telegramId: json['telegramId'] as String?,
      telegramUsername: json['telegramUsername'] as String?,
      botUsername: json['botUsername'] as String?,
    );

Map<String, dynamic> _$TelegramStatusToJson(TelegramStatus instance) =>
    <String, dynamic>{
      'isConnected': instance.isConnected,
      'telegramId': instance.telegramId,
      'telegramUsername': instance.telegramUsername,
      'botUsername': instance.botUsername,
    };

ConnectTelegramRequest _$ConnectTelegramRequestFromJson(
  Map<String, dynamic> json,
) => ConnectTelegramRequest(
  telegramId: json['telegramId'] as String,
  telegramUsername: json['telegramUsername'] as String?,
);

Map<String, dynamic> _$ConnectTelegramRequestToJson(
  ConnectTelegramRequest instance,
) => <String, dynamic>{
  'telegramId': instance.telegramId,
  'telegramUsername': instance.telegramUsername,
};

TelegramLinkToken _$TelegramLinkTokenFromJson(Map<String, dynamic> json) =>
    TelegramLinkToken(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      instructions: (json['instructions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$TelegramLinkTokenToJson(TelegramLinkToken instance) =>
    <String, dynamic>{
      'token': instance.token,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'instructions': instance.instructions,
    };

NotificationHistoryResponse _$NotificationHistoryResponseFromJson(
  Map<String, dynamic> json,
) => NotificationHistoryResponse(
  items: (json['items'] as List<dynamic>)
      .map((e) => NotificationHistoryItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
);

Map<String, dynamic> _$NotificationHistoryResponseToJson(
  NotificationHistoryResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'totalCount': instance.totalCount,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

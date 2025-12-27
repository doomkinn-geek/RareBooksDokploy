// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String?,
  email: json['email'] as String?,
  userName: json['userName'] as String?,
  role: json['role'] as String?,
  hasSubscription: json['hasSubscription'] as bool? ?? false,
  hasCollectionAccess: json['hasCollectionAccess'] as bool? ?? false,
  subscriptionType: json['subscriptionType'] as String?,
  subscriptionExpiryDate: json['subscriptionExpiryDate'] == null
      ? null
      : DateTime.parse(json['subscriptionExpiryDate'] as String),
  currentSubscription: json['currentSubscription'] == null
      ? null
      : CurrentSubscription.fromJson(
          json['currentSubscription'] as Map<String, dynamic>,
        ),
  telegramId: json['telegramId'] as String?,
  telegramUsername: json['telegramUsername'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'userName': instance.userName,
  'role': instance.role,
  'hasSubscription': instance.hasSubscription,
  'hasCollectionAccess': instance.hasCollectionAccess,
  'subscriptionType': instance.subscriptionType,
  'subscriptionExpiryDate': instance.subscriptionExpiryDate?.toIso8601String(),
  'currentSubscription': instance.currentSubscription,
  'telegramId': instance.telegramId,
  'telegramUsername': instance.telegramUsername,
  'createdAt': instance.createdAt?.toIso8601String(),
};

CurrentSubscription _$CurrentSubscriptionFromJson(Map<String, dynamic> json) =>
    CurrentSubscription(
      id: (json['id'] as num?)?.toInt(),
      subscriptionPlanId: (json['subscriptionPlanId'] as num?)?.toInt(),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      isActive: json['isActive'] as bool? ?? false,
      autoRenew: json['autoRenew'] as bool? ?? false,
      usedRequestsThisPeriod: (json['usedRequestsThisPeriod'] as num?)?.toInt(),
      paymentId: json['paymentId'] as String?,
      subscriptionPlan: json['subscriptionPlan'] == null
          ? null
          : SubscriptionPlan.fromJson(
              json['subscriptionPlan'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$CurrentSubscriptionToJson(
  CurrentSubscription instance,
) => <String, dynamic>{
  'id': instance.id,
  'subscriptionPlanId': instance.subscriptionPlanId,
  'startDate': instance.startDate?.toIso8601String(),
  'endDate': instance.endDate?.toIso8601String(),
  'isActive': instance.isActive,
  'autoRenew': instance.autoRenew,
  'usedRequestsThisPeriod': instance.usedRequestsThisPeriod,
  'paymentId': instance.paymentId,
  'subscriptionPlan': instance.subscriptionPlan,
};

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    LoginResponse(
      token: json['token'] as String?,
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{'token': instance.token, 'user': instance.user};

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      name: json['name'] as String?,
      captchaId: json['captchaToken'] as String?,
      captchaAnswer: json['captchaCode'] as String?,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
      'name': instance.name,
      'captchaToken': instance.captchaId,
      'captchaCode': instance.captchaAnswer,
    };

SearchHistoryItem _$SearchHistoryItemFromJson(Map<String, dynamic> json) =>
    SearchHistoryItem(
      id: (json['id'] as num).toInt(),
      searchQuery: json['searchQuery'] as String?,
      searchType: json['searchType'] as String?,
      searchDate: json['searchDate'] == null
          ? null
          : DateTime.parse(json['searchDate'] as String),
      resultsCount: (json['resultsCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SearchHistoryItemToJson(SearchHistoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'searchQuery': instance.searchQuery,
      'searchType': instance.searchType,
      'searchDate': instance.searchDate?.toIso8601String(),
      'resultsCount': instance.resultsCount,
    };

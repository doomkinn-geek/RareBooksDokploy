// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionPlan _$SubscriptionPlanFromJson(Map<String, dynamic> json) =>
    SubscriptionPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      searchLimit: (json['monthlyRequestLimit'] as num?)?.toInt(),
      hasCollectionAccess: json['hasCollectionAccess'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SubscriptionPlanToJson(SubscriptionPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'durationDays': instance.durationDays,
      'monthlyRequestLimit': instance.searchLimit,
      'hasCollectionAccess': instance.hasCollectionAccess,
      'isActive': instance.isActive,
      'sortOrder': instance.sortOrder,
    };

CreatePaymentRequest _$CreatePaymentRequestFromJson(
  Map<String, dynamic> json,
) => CreatePaymentRequest(
  subscriptionPlanId: (json['subscriptionPlanId'] as num).toInt(),
  autoRenew: json['autoRenew'] as bool? ?? false,
);

Map<String, dynamic> _$CreatePaymentRequestToJson(
  CreatePaymentRequest instance,
) => <String, dynamic>{
  'subscriptionPlanId': instance.subscriptionPlanId,
  'autoRenew': instance.autoRenew,
};

CreatePaymentResponse _$CreatePaymentResponseFromJson(
  Map<String, dynamic> json,
) => CreatePaymentResponse(
  redirectUrl: json['redirectUrl'] as String?,
  paymentId: json['paymentId'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$CreatePaymentResponseToJson(
  CreatePaymentResponse instance,
) => <String, dynamic>{
  'redirectUrl': instance.redirectUrl,
  'paymentId': instance.paymentId,
  'status': instance.status,
};

SubscriptionStatus _$SubscriptionStatusFromJson(Map<String, dynamic> json) =>
    SubscriptionStatus(
      hasSubscription: json['hasSubscription'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      planName: json['planName'] as String?,
      hasCollectionAccess: json['hasCollectionAccess'] as bool? ?? false,
    );

Map<String, dynamic> _$SubscriptionStatusToJson(SubscriptionStatus instance) =>
    <String, dynamic>{
      'hasSubscription': instance.hasSubscription,
      'isActive': instance.isActive,
      'expiryDate': instance.expiryDate?.toIso8601String(),
      'planName': instance.planName,
      'hasCollectionAccess': instance.hasCollectionAccess,
    };

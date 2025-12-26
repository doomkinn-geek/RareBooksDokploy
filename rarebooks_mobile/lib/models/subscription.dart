import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart';

/// Subscription plan model
@JsonSerializable()
class SubscriptionPlan {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int durationDays;
  final int? searchLimit;
  final bool hasCollectionAccess;
  final bool isActive;
  final int? sortOrder;
  
  SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationDays,
    this.searchLimit,
    this.hasCollectionAccess = false,
    this.isActive = true,
    this.sortOrder,
  });
  
  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) => 
      _$SubscriptionPlanFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionPlanToJson(this);
  
  /// Get monthly price (if duration > 30 days)
  double get monthlyPrice {
    if (durationDays <= 0) return price;
    return (price / durationDays) * 30;
  }
  
  /// Get duration in months
  int get durationMonths => (durationDays / 30).round();
  
  /// Format duration as human-readable string
  String get durationText {
    if (durationDays <= 30) return '1 месяц';
    if (durationDays <= 90) return '3 месяца';
    if (durationDays <= 180) return '6 месяцев';
    if (durationDays <= 365) return '1 год';
    return '$durationMonths месяцев';
  }
}

/// Create payment request
@JsonSerializable()
class CreatePaymentRequest {
  final int subscriptionPlanId;
  final bool autoRenew;
  
  CreatePaymentRequest({
    required this.subscriptionPlanId,
    this.autoRenew = false,
  });
  
  factory CreatePaymentRequest.fromJson(Map<String, dynamic> json) => 
      _$CreatePaymentRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePaymentRequestToJson(this);
}

/// Create payment response
@JsonSerializable()
class CreatePaymentResponse {
  final String? redirectUrl;
  final String? paymentId;
  final String? status;
  
  CreatePaymentResponse({
    this.redirectUrl,
    this.paymentId,
    this.status,
  });
  
  factory CreatePaymentResponse.fromJson(Map<String, dynamic> json) => 
      _$CreatePaymentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePaymentResponseToJson(this);
}

/// Subscription status response
@JsonSerializable()
class SubscriptionStatus {
  final bool hasSubscription;
  final bool isActive;
  final DateTime? expiryDate;
  final String? planName;
  final bool hasCollectionAccess;
  
  SubscriptionStatus({
    this.hasSubscription = false,
    this.isActive = false,
    this.expiryDate,
    this.planName,
    this.hasCollectionAccess = false,
  });
  
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) => 
      _$SubscriptionStatusFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionStatusToJson(this);
}


import 'package:json_annotation/json_annotation.dart';
import 'subscription.dart';

part 'user.g.dart';

/// User model representing an authenticated user
/// API returns camelCase JSON fields
@JsonSerializable()
class User {
  final String? id;
  final String? email;
  final String? userName;
  final String? role;
  final bool hasSubscription;
  final bool hasCollectionAccess;
  final String? subscriptionType;
  final DateTime? subscriptionExpiryDate;
  final CurrentSubscription? currentSubscription;
  final String? telegramId;
  final String? telegramUsername;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  
  User({
    this.id,
    this.email,
    this.userName,
    this.role,
    this.hasSubscription = false,
    this.hasCollectionAccess = false,
    this.subscriptionType,
    this.subscriptionExpiryDate,
    this.currentSubscription,
    this.telegramId,
    this.telegramUsername,
    this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  /// Get display name
  String get name => userName ?? email ?? 'User';
  
  /// Get numeric ID (parse from string ID)
  int get numericId {
    try {
      return int.tryParse(id ?? '') ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Check if user is admin
  bool get isAdmin => (role ?? '').toLowerCase() == 'admin';
  
  /// Check if Telegram is connected
  bool get isTelegramConnected => telegramId != null && telegramId!.isNotEmpty;
  
  /// Check if subscription is active
  bool get isSubscriptionActive {
    if (!hasSubscription) return false;
    // Check via currentSubscription if available
    if (currentSubscription != null) {
      return currentSubscription!.isActive && 
             currentSubscription!.endDate != null &&
             currentSubscription!.endDate!.isAfter(DateTime.now());
    }
    // Fallback to hasSubscription flag
    return hasSubscription;
  }
}

/// Current subscription details
@JsonSerializable()
class CurrentSubscription {
  final int? id;
  final int? subscriptionPlanId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool autoRenew;
  final int? usedRequestsThisPeriod;
  final String? paymentId;
  final SubscriptionPlan? subscriptionPlan;
  
  CurrentSubscription({
    this.id,
    this.subscriptionPlanId,
    this.startDate,
    this.endDate,
    this.isActive = false,
    this.autoRenew = false,
    this.usedRequestsThisPeriod,
    this.paymentId,
    this.subscriptionPlan,
  });
  
  factory CurrentSubscription.fromJson(Map<String, dynamic> json) => 
      _$CurrentSubscriptionFromJson(json);
  Map<String, dynamic> toJson() => _$CurrentSubscriptionToJson(this);
}

/// Login request model
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;
  
  LoginRequest({
    required this.email,
    required this.password,
  });
  
  factory LoginRequest.fromJson(Map<String, dynamic> json) => 
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

/// Login response model
/// Note: The user object from login response only contains basic fields
/// (email, userName, hasSubscription, role). Call getCurrentUser() for full data.
@JsonSerializable()
class LoginResponse {
  final String? token;
  final User? user;
  
  LoginResponse({
    required this.token,
    this.user,
  });
  
  factory LoginResponse.fromJson(Map<String, dynamic> json) => 
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

/// Register request model
@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  final String? name;
  @JsonKey(name: 'captchaToken')
  final String? captchaId;
  @JsonKey(name: 'captchaCode')
  final String? captchaAnswer;
  
  RegisterRequest({
    required this.email,
    required this.password,
    this.name,
    this.captchaId,
    this.captchaAnswer,
  });
  
  factory RegisterRequest.fromJson(Map<String, dynamic> json) => 
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

/// User search history item
@JsonSerializable()
class SearchHistoryItem {
  final int id;
  final String? searchQuery;
  final String? searchType;
  final DateTime? searchDate;
  final int? resultsCount;
  
  SearchHistoryItem({
    required this.id,
    this.searchQuery,
    this.searchType,
    this.searchDate,
    this.resultsCount,
  });
  
  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) => 
      _$SearchHistoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$SearchHistoryItemToJson(this);
}

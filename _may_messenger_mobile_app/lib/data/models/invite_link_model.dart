class InviteLink {
  final String id;
  final String code;
  final int? usesLeft;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;
  final String? createdById;
  final String? createdByName;

  InviteLink({
    required this.id,
    required this.code,
    this.usesLeft,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
    this.createdById,
    this.createdByName,
  });

  factory InviteLink.fromJson(Map<String, dynamic> json) {
    return InviteLink(
      id: json['id'],
      code: json['code'],
      usesLeft: json['usesLeft'],
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : null,
      isActive: json['isActive'],
      createdAt: DateTime.parse(json['createdAt']),
      createdById: json['createdById'],
      createdByName: json['createdByName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'usesLeft': usesLeft,
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'createdById': createdById,
      'createdByName': createdByName,
    };
  }

  /// Проверяет, истек ли срок действия кода
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Проверяет, исчерпаны ли использования
  bool get isUsedUp {
    if (usesLeft == null) return false;
    return usesLeft! <= 0;
  }

  /// Проверяет, валиден ли код для использования
  bool get isValid {
    return isActive && !isExpired && !isUsedUp;
  }

  /// Статус для отображения
  String get statusMessage {
    if (!isActive) return 'Деактивирован';
    if (isExpired) return 'Истёк';
    if (isUsedUp) return 'Использован';
    return 'Активен';
  }

  /// Форматированная строка для отображения
  String get displayText {
    final buffer = StringBuffer();
    
    if (usesLeft != null) {
      buffer.write('Осталось использований: $usesLeft');
    } else {
      buffer.write('Неограниченные использования');
    }
    
    if (expiresAt != null) {
      final daysLeft = expiresAt!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        buffer.write(' • Истекает через $daysLeft дн.');
      } else if (daysLeft == 0) {
        buffer.write(' • Истекает сегодня');
      } else {
        buffer.write(' • Истёк');
      }
    }
    
    return buffer.toString();
  }
}

/// Response from invite code validation
class InviteCodeValidation {
  final bool isValid;
  final String message;
  final String? creatorName;
  final int? usesLeft;
  final DateTime? expiresAt;

  InviteCodeValidation({
    required this.isValid,
    required this.message,
    this.creatorName,
    this.usesLeft,
    this.expiresAt,
  });

  factory InviteCodeValidation.fromJson(Map<String, dynamic> json) {
    return InviteCodeValidation(
      isValid: json['isValid'] ?? false,
      message: json['message'] ?? '',
      creatorName: json['creatorName'],
      usesLeft: json['usesLeft'],
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : null,
    );
  }
}


class InviteLink {
  final String id;
  final String code;
  final int? usesLeft;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  InviteLink({
    required this.id,
    required this.code,
    this.usesLeft,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
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

  /// Форматированная строка для отображения
  String get displayText {
    final buffer = StringBuffer('Код: $code');
    
    if (usesLeft != null) {
      buffer.write(' (осталось: $usesLeft)');
    }
    
    if (expiresAt != null) {
      final daysLeft = expiresAt!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        buffer.write(' - истекает через $daysLeft дн.');
      } else if (daysLeft == 0) {
        buffer.write(' - истекает сегодня');
      } else {
        buffer.write(' - истек');
      }
    }
    
    return buffer.toString();
  }
}


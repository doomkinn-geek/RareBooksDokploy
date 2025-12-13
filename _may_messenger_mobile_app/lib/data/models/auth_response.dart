class AuthResponse {
  final bool success;
  final String token;
  final String message;

  AuthResponse({
    required this.success,
    required this.token,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'],
      token: json['token'],
      message: json['message'],
    );
  }
}



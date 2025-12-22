import '../datasources/api_datasource.dart';

class UserStatusDto {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeenAt;
  
  UserStatusDto({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });
  
  factory UserStatusDto.fromJson(Map<String, dynamic> json) {
    return UserStatusDto(
      userId: json['userId'] as String,
      isOnline: json['isOnline'] as bool,
      lastSeenAt: json['lastSeenAt'] != null 
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
    );
  }
}

class UserRepository {
  final ApiDataSource _apiDataSource;
  
  UserRepository(this._apiDataSource);
  
  /// Get online/offline status for multiple users
  Future<List<UserStatusDto>> getUsersStatus(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    try {
      // Build query string: ?userIds=id1&userIds=id2&userIds=id3
      final queryParams = userIds.map((id) => 'userIds=$id').join('&');
      
      final response = await _apiDataSource.dio.get(
        '/users/status?$queryParams',
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        return jsonList.map((json) => UserStatusDto.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users status: ${response.statusCode}');
      }
    } catch (e) {
      print('[UserRepository] Error getting user statuses: $e');
      // Return empty list instead of throwing - don't break the app
      return [];
    }
  }
}


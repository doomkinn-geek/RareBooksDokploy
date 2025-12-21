import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/search_result_model.dart';
import '../models/chat_model.dart';

class SearchService {
  final Dio _dio;

  SearchService(this._dio);

  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/api/users/search',
        queryParameters: {'query': query},
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => User.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('[SearchService] Error searching users: $e');
      rethrow;
    }
  }

  Future<List<Chat>> searchChats(String query) async {
    try {
      final response = await _dio.get(
        '/api/chats/search',
        queryParameters: {'query': query},
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Chat.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('[SearchService] Error searching chats: $e');
      rethrow;
    }
  }

  Future<List<MessageSearchResult>> searchMessages(String query) async {
    try {
      final response = await _dio.get(
        '/api/messages/search',
        queryParameters: {'query': query},
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => MessageSearchResult.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('[SearchService] Error searching messages: $e');
      rethrow;
    }
  }
}


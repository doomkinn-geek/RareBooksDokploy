import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final Dio _dio = Dio();
  bool _enabled = true;

  void enable() => _enabled = true;
  void disable() => _enabled = false;

  Future<void> log(
    String level,
    String location,
    String message,
    Map<String, dynamic> data,
  ) async {
    if (!_enabled) return;

    try {
      await Future.any([
        _dio.post(
          '${ApiConstants.baseUrl}/api/clientlogs',
          data: {
            'timestamp': DateTime.now().toIso8601String(),
            'level': level,
            'location': location,
            'message': message,
            'data': data.map((k, v) => MapEntry(k, v.toString())),
          },
        ),
        Future.delayed(const Duration(milliseconds: 500)),
      ]);
    } catch (_) {
      // Silently fail - logging should not crash the app
    }
  }

  Future<void> debug(String location, String message, [Map<String, dynamic>? data]) {
    return log('DEBUG', location, message, data ?? {});
  }

  Future<void> info(String location, String message, [Map<String, dynamic>? data]) {
    return log('INFO', location, message, data ?? {});
  }

  Future<void> error(String location, String message, [Map<String, dynamic>? data]) {
    return log('ERROR', location, message, data ?? {});
  }
}


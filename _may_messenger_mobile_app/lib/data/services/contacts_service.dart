import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

class ContactsService {
  final Dio _dio;

  ContactsService(this._dio);

  String hashPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Compute SHA256 hash
    final bytes = utf8.encode(cleaned);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission();
  }

  Future<List<Contact>> getAllContacts() async {
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission not granted');
    }

    return await FlutterContacts.getContacts(withProperties: true);
  }

  Future<List<RegisteredContact>> syncContacts(String token) async {
    try {
      // #region agent log
      await _dio.post('${ApiConstants.baseUrl}/api/Diagnostics/logs', data: {'location': 'contacts_service.dart:39', 'message': '[H1,H2] syncContacts entry', 'data': {'hasToken': token.isNotEmpty}, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': 'H1,H2'}).catchError((_) {});
      // #endregion
      
      // Get all contacts from phone
      final contacts = await getAllContacts();
      
      // #region agent log
      await _dio.post('${ApiConstants.baseUrl}/api/Diagnostics/logs', data: {'location': 'contacts_service.dart:48', 'message': '[H1] Contacts from phone', 'data': {'totalCount': contacts.length, 'withPhones': contacts.where((c) => c.phones.isNotEmpty).length}, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': 'H1'}).catchError((_) {});
      // #endregion
      
      // Prepare contacts data for sync
      final contactsData = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) {
            final phoneNumber = c.phones.first.number;
            final displayName = c.displayName;
            final hash = hashPhoneNumber(phoneNumber);
            
            // #region agent log
            _dio.post('${ApiConstants.baseUrl}/api/Diagnostics/logs', data: {'location': 'contacts_service.dart:60', 'message': '[H2] Processing contact', 'data': {'phoneNumber': phoneNumber, 'hash': hash, 'displayName': displayName}, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': 'H2'}).catchError((_) {});
            // #endregion
            
            return {
              'phoneNumberHash': hash,
              'displayName': displayName,
            };
          })
          .toList();

      // #region agent log
      await _dio.post('${ApiConstants.baseUrl}/api/Diagnostics/logs', data: {'location': 'contacts_service.dart:72', 'message': '[H2,H3] Sending to backend', 'data': {'contactsToSend': contactsData.length, 'firstThree': contactsData.take(3).toList()}, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': 'H2,H3'}).catchError((_) {});
      // #endregion

      // Send to backend
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/api/contacts/sync',
        data: {
          'contacts': contactsData,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      // #region agent log
      await _dio.post('${ApiConstants.baseUrl}/api/Diagnostics/logs', data: {'location': 'contacts_service.dart:89', 'message': '[H3,H4] Backend response', 'data': {'statusCode': response.statusCode, 'dataType': response.data.runtimeType.toString(), 'dataLength': (response.data as List?)?.length ?? 0}, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': 'H3,H4'}).catchError((_) {});
      // #endregion

      // Parse response
      final List<dynamic> data = response.data;
      return data.map((json) => RegisteredContact.fromJson(json)).toList();
    } catch (e) {
      // #region agent log
      await _dio.post('${ApiConstants.baseUrl}/api/Diagnostics/logs', data: {'location': 'contacts_service.dart:99', 'message': '[H1,H2,H3] syncContacts error', 'data': {'error': e.toString(), 'errorType': e.runtimeType.toString()}, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': 'H1,H2,H3'}).catchError((_) {});
      // #endregion
      
      print('Failed to sync contacts: $e');
      rethrow;
    }
  }

  Future<List<RegisteredContact>> getRegisteredContacts(String token) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/api/contacts/registered',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final List<dynamic> data = response.data;
      return data.map((json) => RegisteredContact.fromJson(json)).toList();
    } catch (e) {
      print('Failed to get registered contacts: $e');
      rethrow;
    }
  }
}

class RegisteredContact {
  final String userId;
  final String phoneNumberHash;
  final String displayName;

  RegisteredContact({
    required this.userId,
    required this.phoneNumberHash,
    required this.displayName,
  });

  factory RegisteredContact.fromJson(Map<String, dynamic> json) {
    return RegisteredContact(
      userId: json['userId'] as String,
      phoneNumberHash: json['phoneNumberHash'] as String,
      displayName: json['displayName'] as String,
    );
  }
}

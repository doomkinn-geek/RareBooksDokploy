import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

class ContactsService {
  final Dio _dio;

  ContactsService(this._dio);

  /// Нормализует номер телефона перед хешированием.
  /// Удаляет все символы кроме цифр, заменяет начальную "8" на "+7".
  /// Примеры:
  /// "+7 (909) 492-41-90" -> "+79094924190"
  /// "8 (909) 492-41-90"  -> "+79094924190"
  /// "8-909-492-41-90"    -> "+79094924190"
  String normalizePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return '';
    }

    // Удаляем все символы кроме цифр и +
    var cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Заменяем начальную 8 на +7 (для российских номеров)
    if (cleaned.startsWith('8') && cleaned.length == 11) {
      cleaned = '+7${cleaned.substring(1)}';
    }
    
    // Если номер начинается с 7 (без +), добавляем +
    if (cleaned.startsWith('7') && cleaned.length == 11 && !cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    
    return cleaned;
  }

  String hashPhoneNumber(String phoneNumber) {
    // Normalize phone number before hashing
    final normalized = normalizePhoneNumber(phoneNumber);
    
    // Compute SHA256 hash
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission();
  }

  Future<List<Contact>> getAllContacts() async {
    // Permission is already checked in the calling code using permission_handler
    // FlutterContacts.requestPermission() has a bug and returns false even when granted
    return await FlutterContacts.getContacts(withProperties: true);
  }

  Future<List<RegisteredContact>> syncContacts(String token) async {
    try {
      // Get all contacts from phone
      final contacts = await getAllContacts();
      
      // Prepare contacts data for sync
      final contactsData = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) {
            final phoneNumber = c.phones.first.number;
            final displayName = c.displayName;
            final hash = hashPhoneNumber(phoneNumber);
            
            return {
              'phoneNumberHash': hash,
              'displayName': displayName,
            };
          })
          .toList();

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

      // Parse response
      final List<dynamic> data = response.data;
      return data.map((json) => RegisteredContact.fromJson(json)).toList();
    } catch (e) {
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

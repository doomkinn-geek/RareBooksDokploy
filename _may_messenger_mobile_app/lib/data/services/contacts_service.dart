import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:contacts_service/contacts_service.dart' as contacts_pkg;
import 'package:permission_handler/permission_handler.dart';
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
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<List<contacts_pkg.Contact>> getAllContacts() async {
    final hasPermission = await Permission.contacts.isGranted;
    if (!hasPermission) {
      throw Exception('Contacts permission not granted');
    }

    return await contacts_pkg.ContactsService.getContacts();
  }

  Future<List<RegisteredContact>> syncContacts(String token) async {
    try {
      // Get all contacts from phone
      final contacts = await getAllContacts();
      
      // Prepare contacts data for sync
      final contactsData = contacts
          .where((c) => c.phones != null && c.phones!.isNotEmpty)
          .map((c) {
            final phoneNumber = c.phones!.first.value ?? '';
            final displayName = c.displayName ?? '';
            
            return {
              'phoneNumberHash': hashPhoneNumber(phoneNumber),
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

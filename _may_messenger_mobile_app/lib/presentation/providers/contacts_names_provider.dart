import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/services/contacts_service.dart';
import 'auth_provider.dart';

/// Provider for contacts service
final contactsServiceForNamesProvider = Provider((ref) => ContactsService(Dio()));

/// Provider that holds mapping of userId -> displayName from phone contacts
final contactsNamesProvider = StateNotifierProvider<ContactsNamesNotifier, Map<String, String>>(
  (ref) => ContactsNamesNotifier(
    ref.read(contactsServiceForNamesProvider),
    ref,
  ),
);

class ContactsNamesNotifier extends StateNotifier<Map<String, String>> {
  final ContactsService _contactsService;
  final Ref _ref;

  ContactsNamesNotifier(this._contactsService, this._ref) : super({});

  /// Load contacts and build userId -> displayName mapping
  /// Safe to call - will not crash if permission denied
  Future<void> loadContactsMapping() async {
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final token = await authRepo.getStoredToken();
      
      if (token == null) {
        return;
      }

      // Sync contacts with backend and get registered contacts
      // This may fail if permission is not granted - that's OK
      final registeredContacts = await _contactsService.syncContacts(token);
      
      // Build mapping userId -> displayName
      final mapping = <String, String>{};
      for (final contact in registeredContacts) {
        mapping[contact.userId] = contact.displayName;
      }
      
      state = mapping;
    } catch (e) {
      // Silently fail if contacts permission not granted
      // User will see server names instead of contact names
      print('Failed to load contacts mapping (permission may be denied): $e');
      state = {}; // Empty mapping
    }
  }

  /// Get display name for userId, returns null if not found
  String? getDisplayName(String userId) {
    return state[userId];
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/services/contacts_service.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/contact_cache_model.dart';
import 'auth_provider.dart';

/// Provider for contacts service
final contactsServiceForNamesProvider = Provider((ref) => ContactsService(Dio()));

/// Provider for local data source
final localDataSourceForContactsProvider = Provider((ref) => LocalDataSource());

/// Provider that holds mapping of userId -> displayName from phone contacts
final contactsNamesProvider = StateNotifierProvider<ContactsNamesNotifier, Map<String, String>>(
  (ref) => ContactsNamesNotifier(
    ref.read(contactsServiceForNamesProvider),
    ref.read(localDataSourceForContactsProvider),
    ref,
  ),
);

class ContactsNamesNotifier extends StateNotifier<Map<String, String>> {
  final ContactsService _contactsService;
  final LocalDataSource _localDataSource;
  final Ref _ref;

  ContactsNamesNotifier(this._contactsService, this._localDataSource, this._ref) : super({}) {
    _loadCachedContacts();
  }

  /// Load cached contacts on initialization
  Future<void> _loadCachedContacts() async {
    try {
      final cachedContacts = await _localDataSource.getContactsCache();
      if (cachedContacts != null && cachedContacts.isNotEmpty) {
        final mapping = <String, String>{};
        for (final contact in cachedContacts) {
          mapping[contact.userId] = contact.displayName;
        }
        state = mapping;
        print('[ContactsNames] Loaded ${mapping.length} contacts from cache');
      }
    } catch (e) {
      print('[ContactsNames] Failed to load cached contacts: $e');
    }
  }

  /// Load contacts and build userId -> displayName mapping
  /// Safe to call - will not crash if permission denied
  Future<void> loadContactsMapping() async {
    print('[ContactsNames] Starting to load contacts mapping');
    
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final token = await authRepo.getStoredToken();
      
      if (token == null) {
        print('[ContactsNames] No token available, skipping');
        return;
      }

      print('[ContactsNames] Syncing contacts with backend');

      // Sync contacts with backend and get registered contacts
      // This may fail if permission is not granted - that's OK
      final registeredContacts = await _contactsService.syncContacts(token);
      
      print('[ContactsNames] Synced ${registeredContacts.length} registered contacts');
      
      // Get local contacts to build name mapping from phone book
      final localContacts = await _contactsService.getAllContacts();
      
      // Build mapping userId -> displayName from phone book
      final mapping = <String, String>{};
      final cacheList = <ContactCache>[];
      
      for (final registered in registeredContacts) {
        // Try to find matching local contact by phone hash
        String? phoneBookName;
        
        for (final local in localContacts) {
          if (local.phones.isNotEmpty) {
            final hash = _contactsService.hashPhoneNumber(local.phones.first.number);
            
            if (hash == registered.phoneNumberHash) {
              // Found match - use phone book name
              phoneBookName = local.displayName;
              break;
            }
          }
        }
        
        // Use phone book name if found, otherwise fallback to server name
        final displayName = phoneBookName ?? registered.displayName;
        mapping[registered.userId] = displayName;
        
        // Add to cache list
        cacheList.add(ContactCache(
          userId: registered.userId,
          displayName: displayName,
          phoneNumberHash: registered.phoneNumberHash,
          cachedAt: DateTime.now(),
        ));
      }
      
      print('[ContactsNames] Mapping built with ${mapping.length} entries from phone book');
      
      // Save to cache
      await _localDataSource.saveContactsCache(cacheList);
      
      state = mapping;
    } catch (e) {
      // Silently fail if contacts permission not granted
      // User will see server names instead of contact names
      print('[ContactsNames] Failed to load contacts mapping: $e');
      
      state = {}; // Empty mapping
    }
  }

  /// Get display name for userId, returns null if not found
  String? getDisplayName(String userId) {
    return state[userId];
  }
}

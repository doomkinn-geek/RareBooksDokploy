import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Service for caching user avatars locally with async update checking
/// This prevents repeated downloads and reduces bandwidth usage
class AvatarCacheService {
  static final AvatarCacheService _instance = AvatarCacheService._internal();
  factory AvatarCacheService() => _instance;
  AvatarCacheService._internal();
  
  Directory? _cacheDir;
  final Map<String, String> _avatarHashes = {}; // userId -> last known hash/etag
  final Map<String, DateTime> _lastChecked = {}; // userId -> last check time
  final Set<String> _pendingChecks = {}; // Currently checking users
  
  // Check interval - don't check same avatar more than once per 5 minutes
  static const Duration _checkInterval = Duration(minutes: 5);
  
  /// Initialize the cache directory
  Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/avatar_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // Load hash metadata from file
      await _loadMetadata();
      
      print('[AVATAR_CACHE] Initialized at: ${_cacheDir!.path}');
    } catch (e) {
      print('[AVATAR_CACHE] Failed to initialize: $e');
    }
  }
  
  /// Get local path for avatar (null if not cached)
  String? getLocalPath(String? userId) {
    if (userId == null || _cacheDir == null) return null;
    
    final file = File('${_cacheDir!.path}/$userId.jpg');
    if (file.existsSync()) {
      return file.path;
    }
    return null;
  }
  
  /// Get local path or download avatar
  /// Returns local path if cached, otherwise triggers async download and returns null
  Future<String?> getOrDownloadAvatar(String? userId, String? avatarUrl) async {
    if (userId == null || avatarUrl == null || _cacheDir == null) return null;
    
    final localPath = getLocalPath(userId);
    
    if (localPath != null) {
      // Avatar is cached - trigger async check for updates (non-blocking)
      _checkForUpdateAsync(userId, avatarUrl);
      return localPath;
    }
    
    // Not cached - download
    return await _downloadAvatar(userId, avatarUrl);
  }
  
  /// Synchronously get cached path (for widget build)
  /// Returns null if not cached or if user has no avatar set
  /// IMPORTANT: If avatarUrl is null, user has no avatar - don't return cached file
  String? getCachedPath(String? userId, String? avatarUrl) {
    if (userId == null || _cacheDir == null) return null;
    
    // CRITICAL FIX: If avatarUrl is null, user has no avatar set
    // Don't return any cached file - this prevents showing wrong avatar
    if (avatarUrl == null) {
      return null;
    }
    
    final localPath = getLocalPath(userId);
    
    if (localPath != null) {
      // Cached - trigger async update check
      _checkForUpdateAsync(userId, avatarUrl);
      return localPath;
    }
    
    // Not cached - trigger async download
    _downloadAvatarAsync(userId, avatarUrl);
    
    return null;
  }
  
  /// Trigger async download (fire and forget)
  void _downloadAvatarAsync(String userId, String avatarUrl) {
    if (_pendingChecks.contains(userId)) return;
    _pendingChecks.add(userId);
    
    _downloadAvatar(userId, avatarUrl).then((_) {
      _pendingChecks.remove(userId);
    }).catchError((e) {
      _pendingChecks.remove(userId);
      print('[AVATAR_CACHE] Async download failed for $userId: $e');
    });
  }
  
  /// Download avatar and save to cache
  Future<String?> _downloadAvatar(String userId, String avatarUrl) async {
    try {
      final fullUrl = avatarUrl.startsWith('http') 
          ? avatarUrl 
          : '${ApiConstants.baseUrl}$avatarUrl';
      
      print('[AVATAR_CACHE] Downloading avatar for $userId from $fullUrl');
      
      final response = await http.get(Uri.parse(fullUrl));
      
      if (response.statusCode == 200) {
        final file = File('${_cacheDir!.path}/$userId.jpg');
        await file.writeAsBytes(response.bodyBytes);
        
        // Save ETag for future update checks
        final etag = response.headers['etag'];
        if (etag != null) {
          _avatarHashes[userId] = etag;
          await _saveMetadata();
        }
        
        _lastChecked[userId] = DateTime.now();
        
        print('[AVATAR_CACHE] Avatar cached for $userId');
        return file.path;
      } else {
        print('[AVATAR_CACHE] Failed to download avatar: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[AVATAR_CACHE] Error downloading avatar: $e');
      return null;
    }
  }
  
  /// Check for avatar update asynchronously
  void _checkForUpdateAsync(String userId, String avatarUrl) {
    // Throttle checks
    final lastCheck = _lastChecked[userId];
    if (lastCheck != null && 
        DateTime.now().difference(lastCheck) < _checkInterval) {
      return; // Checked recently, skip
    }
    
    if (_pendingChecks.contains(userId)) return;
    _pendingChecks.add(userId);
    
    _checkForUpdate(userId, avatarUrl).then((_) {
      _pendingChecks.remove(userId);
    }).catchError((e) {
      _pendingChecks.remove(userId);
    });
  }
  
  /// Check if avatar has been updated on server using HEAD request
  Future<void> _checkForUpdate(String userId, String avatarUrl) async {
    try {
      final fullUrl = avatarUrl.startsWith('http') 
          ? avatarUrl 
          : '${ApiConstants.baseUrl}$avatarUrl';
      
      final response = await http.head(Uri.parse(fullUrl));
      
      _lastChecked[userId] = DateTime.now();
      
      if (response.statusCode == 200) {
        final serverEtag = response.headers['etag'];
        final cachedEtag = _avatarHashes[userId];
        
        if (serverEtag != null && cachedEtag != null && serverEtag != cachedEtag) {
          // Avatar has changed - redownload
          print('[AVATAR_CACHE] Avatar changed for $userId, redownloading...');
          await _downloadAvatar(userId, avatarUrl);
        }
      }
    } catch (e) {
      // Silent fail - don't spam logs for network issues
    }
  }
  
  /// Clear cache for a specific user
  Future<void> clearCache(String userId) async {
    try {
      final file = File('${_cacheDir!.path}/$userId.jpg');
      if (await file.exists()) {
        await file.delete();
      }
      _avatarHashes.remove(userId);
      _lastChecked.remove(userId);
      await _saveMetadata();
    } catch (e) {
      print('[AVATAR_CACHE] Error clearing cache for $userId: $e');
    }
  }
  
  /// Clear entire cache
  Future<void> clearAllCache() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create();
      }
      _avatarHashes.clear();
      _lastChecked.clear();
      print('[AVATAR_CACHE] All cache cleared');
    } catch (e) {
      print('[AVATAR_CACHE] Error clearing all cache: $e');
    }
  }
  
  /// Save metadata to file
  Future<void> _saveMetadata() async {
    if (_cacheDir == null) return;
    
    try {
      final metaFile = File('${_cacheDir!.path}/metadata.json');
      final data = json.encode(_avatarHashes);
      await metaFile.writeAsString(data);
    } catch (e) {
      print('[AVATAR_CACHE] Error saving metadata: $e');
    }
  }
  
  /// Load metadata from file
  Future<void> _loadMetadata() async {
    if (_cacheDir == null) return;
    
    try {
      final metaFile = File('${_cacheDir!.path}/metadata.json');
      if (await metaFile.exists()) {
        final data = await metaFile.readAsString();
        final decoded = json.decode(data) as Map<String, dynamic>;
        _avatarHashes.clear();
        decoded.forEach((key, value) {
          _avatarHashes[key] = value.toString();
        });
        print('[AVATAR_CACHE] Loaded metadata for ${_avatarHashes.length} avatars');
      }
    } catch (e) {
      print('[AVATAR_CACHE] Error loading metadata: $e');
    }
  }
}

/// Global instance
final avatarCacheService = AvatarCacheService();


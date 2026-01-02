import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for end-to-end encryption using X25519 ECDH and AES-256-GCM
class EncryptionService {
  static const String _privateKeyStorageKey = 'e2e_private_key';
  static const String _publicKeyStorageKey = 'e2e_public_key';
  
  final FlutterSecureStorage _secureStorage;
  final X25519 _x25519 = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  // HKDF with 256-bit output for AES-256 keys
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  
  // Cache for session keys (chatId -> derived key)
  final Map<String, SecretKey> _sessionKeyCache = {};
  
  // Cached key pair
  SimpleKeyPair? _keyPair;
  
  EncryptionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );
  
  /// Initialize encryption service - load or generate key pair
  Future<void> initialize() async {
    try {
      // Try to load existing keys
      final privateKeyBase64 = await _secureStorage.read(key: _privateKeyStorageKey);
      final publicKeyBase64 = await _secureStorage.read(key: _publicKeyStorageKey);
      
      if (privateKeyBase64 != null && publicKeyBase64 != null) {
        // Reconstruct key pair from stored keys
        final privateKeyBytes = base64Decode(privateKeyBase64);
        final publicKeyBytes = base64Decode(publicKeyBase64);
        
        _keyPair = SimpleKeyPairData(
          privateKeyBytes,
          publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
        print('[ENCRYPTION] Loaded existing key pair');
      } else {
        // Generate new key pair
        await _generateAndStoreKeyPair();
      }
    } catch (e) {
      print('[ENCRYPTION] Error initializing: $e');
      // Generate new key pair on error
      await _generateAndStoreKeyPair();
    }
  }
  
  /// Generate new key pair and store securely
  Future<void> _generateAndStoreKeyPair() async {
    _keyPair = await _x25519.newKeyPair();
    
    // Store private key securely
    final privateKeyBytes = await _keyPair!.extractPrivateKeyBytes();
    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(privateKeyBytes),
    );
    
    // Store public key
    final publicKey = await _keyPair!.extractPublicKey();
    await _secureStorage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(publicKey.bytes),
    );
    
    print('[ENCRYPTION] Generated and stored new key pair');
  }
  
  /// Get current user's public key as Base64 string
  Future<String?> getPublicKeyBase64() async {
    if (_keyPair == null) {
      await initialize();
    }
    
    if (_keyPair == null) return null;
    
    final publicKey = await _keyPair!.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }
  
  /// Check if encryption keys are available
  Future<bool> hasKeys() async {
    if (_keyPair != null) return true;
    
    final privateKey = await _secureStorage.read(key: _privateKeyStorageKey);
    return privateKey != null;
  }
  
  /// Derive session key for a private chat using ECDH
  /// The key is derived from the shared secret between our private key and their public key
  Future<SecretKey> deriveSessionKey(String chatId, String otherUserPublicKeyBase64) async {
    // Check cache first
    if (_sessionKeyCache.containsKey(chatId)) {
      return _sessionKeyCache[chatId]!;
    }
    
    if (_keyPair == null) {
      await initialize();
    }
    
    // Parse other user's public key
    final otherPublicKeyBytes = base64Decode(otherUserPublicKeyBase64);
    final otherPublicKey = SimplePublicKey(otherPublicKeyBytes, type: KeyPairType.x25519);
    
    // Perform ECDH to get shared secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: otherPublicKey,
    );
    
    // Derive session key using HKDF
    // Use chatId as info to make key unique per chat
    final sessionKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: <int>[], // Empty nonce (salt) - we use info for uniqueness
      info: utf8.encode('MayMessenger-E2E-$chatId'),
    );
    
    // Cache the key
    _sessionKeyCache[chatId] = sessionKey;
    
    print('[ENCRYPTION] Derived session key for chat $chatId');
    return sessionKey;
  }
  
  /// Set pre-computed session key for a group chat
  void setGroupSessionKey(String chatId, SecretKey key) {
    _sessionKeyCache[chatId] = key;
    print('[ENCRYPTION] Set group session key for chat $chatId');
  }
  
  /// Clear session key cache for a chat
  void clearSessionKey(String chatId) {
    _sessionKeyCache.remove(chatId);
  }
  
  /// Clear all cached session keys
  void clearAllSessionKeys() {
    _sessionKeyCache.clear();
  }
  
  /// Encrypt a message using AES-256-GCM
  /// Returns Base64 encoded string: nonce(12 bytes) + ciphertext + tag(16 bytes)
  Future<String> encrypt(String plaintext, SecretKey sessionKey) async {
    final plaintextBytes = utf8.encode(plaintext);
    
    // Generate random nonce (12 bytes for AES-GCM)
    final nonce = _aesGcm.newNonce();
    
    // Encrypt
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: sessionKey,
      nonce: nonce,
    );
    
    // Combine nonce + ciphertext + mac into single bytes
    final combined = Uint8List(nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length);
    combined.setAll(0, nonce);
    combined.setAll(nonce.length, secretBox.cipherText);
    combined.setAll(nonce.length + secretBox.cipherText.length, secretBox.mac.bytes);
    
    return base64Encode(combined);
  }
  
  /// Decrypt a message using AES-256-GCM
  /// Input should be Base64 encoded: nonce(12 bytes) + ciphertext + tag(16 bytes)
  Future<String> decrypt(String encryptedBase64, SecretKey sessionKey) async {
    final combined = base64Decode(encryptedBase64);
    
    // Extract components
    const nonceLength = 12;
    const macLength = 16;
    
    if (combined.length < nonceLength + macLength) {
      throw FormatException('Invalid encrypted data length');
    }
    
    final nonce = combined.sublist(0, nonceLength);
    final ciphertext = combined.sublist(nonceLength, combined.length - macLength);
    final mac = combined.sublist(combined.length - macLength);
    
    // Create SecretBox
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );
    
    // Decrypt
    final plaintextBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: sessionKey,
    );
    
    return utf8.decode(plaintextBytes);
  }
  
  /// Encrypt a message for a specific chat (convenience method)
  Future<String?> encryptForChat(String chatId, String plaintext, String? otherUserPublicKey) async {
    if (otherUserPublicKey == null || otherUserPublicKey.isEmpty) {
      print('[ENCRYPTION] No public key available for chat $chatId');
      return null;
    }
    
    try {
      final sessionKey = await deriveSessionKey(chatId, otherUserPublicKey);
      return await encrypt(plaintext, sessionKey);
    } catch (e) {
      print('[ENCRYPTION] Failed to encrypt for chat $chatId: $e');
      return null;
    }
  }
  
  /// Decrypt a message from a specific chat (convenience method)
  Future<String?> decryptFromChat(String chatId, String encryptedBase64, String? otherUserPublicKey) async {
    if (otherUserPublicKey == null || otherUserPublicKey.isEmpty) {
      print('[ENCRYPTION] No public key available for chat $chatId');
      return null;
    }
    
    try {
      final sessionKey = await deriveSessionKey(chatId, otherUserPublicKey);
      return await decrypt(encryptedBase64, sessionKey);
    } catch (e) {
      print('[ENCRYPTION] Failed to decrypt for chat $chatId: $e');
      return null;
    }
  }
  
  /// Generate a random AES-256 key for group chats
  Future<SecretKey> generateGroupKey() async {
    return await _aesGcm.newSecretKey();
  }
  
  /// Export secret key as Base64 (for group key distribution)
  Future<String> exportSecretKey(SecretKey key) async {
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }
  
  /// Import secret key from Base64 (for group key distribution)
  SecretKey importSecretKey(String base64Key) {
    final bytes = base64Decode(base64Key);
    return SecretKeyData(bytes);
  }
  
  /// Encrypt group key with a user's public key (for distribution)
  Future<String> encryptGroupKeyForUser(SecretKey groupKey, String userPublicKeyBase64) async {
    if (_keyPair == null) {
      await initialize();
    }
    
    // For simplicity, we'll use a derived key from ECDH with the user's public key
    // In a more sophisticated implementation, we'd use proper key encapsulation
    final userPublicKeyBytes = base64Decode(userPublicKeyBase64);
    final userPublicKey = SimplePublicKey(userPublicKeyBytes, type: KeyPairType.x25519);
    
    // Perform ECDH
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: userPublicKey,
    );
    
    // Derive encryption key
    final encryptionKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: <int>[], // Empty nonce (salt)
      info: utf8.encode('MayMessenger-GroupKey-Wrap'),
    );
    
    // Encrypt the group key
    final groupKeyBytes = await groupKey.extractBytes();
    return await encrypt(base64Encode(groupKeyBytes), encryptionKey);
  }
  
  /// Decrypt group key that was encrypted for us
  Future<SecretKey> decryptGroupKeyFromUser(String encryptedGroupKey, String senderPublicKeyBase64) async {
    if (_keyPair == null) {
      await initialize();
    }
    
    // Parse sender's public key
    final senderPublicKeyBytes = base64Decode(senderPublicKeyBase64);
    final senderPublicKey = SimplePublicKey(senderPublicKeyBytes, type: KeyPairType.x25519);
    
    // Perform ECDH
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: senderPublicKey,
    );
    
    // Derive encryption key
    final encryptionKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: <int>[], // Empty nonce (salt)
      info: utf8.encode('MayMessenger-GroupKey-Wrap'),
    );

    // Decrypt the group key
    final decryptedBase64 = await decrypt(encryptedGroupKey, encryptionKey);
    final groupKeyBytes = base64Decode(decryptedBase64);
    
    return SecretKeyData(groupKeyBytes);
  }
  
  /// Clear all stored keys (for logout)
  Future<void> clearAllKeys() async {
    await _secureStorage.delete(key: _privateKeyStorageKey);
    await _secureStorage.delete(key: _publicKeyStorageKey);
    _keyPair = null;
    _sessionKeyCache.clear();
    print('[ENCRYPTION] Cleared all encryption keys');
  }
}

/// Provider for EncryptionService
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});


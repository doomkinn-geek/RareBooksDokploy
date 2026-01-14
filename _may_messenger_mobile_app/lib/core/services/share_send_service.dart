import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../data/models/message_model.dart';
import '../../core/constants/api_constants.dart';

/// Provider for the share send service
final shareSendServiceProvider = Provider<ShareSendService>((ref) {
  return ShareSendService();
});

/// Service to share content to other apps
/// Uses share_plus package
class ShareSendService {
  
  /// Share text content to other apps
  Future<ShareResult> shareText(String text, {String? subject, Rect? sharePositionOrigin}) async {
    try {
      final result = await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: Platform.isIOS 
            ? (sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100)) 
            : null,
      );
      print('[ShareSendService] Text shared, result: ${result.status}');
      return result;
    } catch (e) {
      print('[ShareSendService] Error sharing text: $e');
      rethrow;
    }
  }
  
  /// Share a single file to other apps
  Future<ShareResult> shareFile(String filePath, {String? mimeType, String? text, Rect? sharePositionOrigin}) async {
    try {
      final file = XFile(filePath, mimeType: mimeType);
      final result = await Share.shareXFiles(
        [file],
        text: text,
        sharePositionOrigin: Platform.isIOS 
            ? (sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100)) 
            : null,
      );
      print('[ShareSendService] File shared, result: ${result.status}');
      return result;
    } catch (e) {
      print('[ShareSendService] Error sharing file: $e');
      rethrow;
    }
  }
  
  /// Share an image file to other apps
  Future<ShareResult> shareImage(String imagePath, {String? text, Rect? sharePositionOrigin}) async {
    return shareFile(imagePath, mimeType: 'image/*', text: text, sharePositionOrigin: sharePositionOrigin);
  }
  
  /// Share an audio file to other apps
  Future<ShareResult> shareAudio(String audioPath, {String? text, Rect? sharePositionOrigin}) async {
    return shareFile(audioPath, mimeType: 'audio/*', text: text, sharePositionOrigin: sharePositionOrigin);
  }
  
  /// Share multiple files to other apps
  Future<ShareResult> shareMultiple(List<String> filePaths, {String? text, Rect? sharePositionOrigin}) async {
    try {
      final files = filePaths.map((path) => XFile(path)).toList();
      final result = await Share.shareXFiles(
        files,
        text: text,
        sharePositionOrigin: Platform.isIOS 
            ? (sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100)) 
            : null,
      );
      print('[ShareSendService] Multiple files shared, result: ${result.status}');
      return result;
    } catch (e) {
      print('[ShareSendService] Error sharing multiple files: $e');
      rethrow;
    }
  }
  
  /// Download file from server URL to local storage
  Future<String?> _downloadFileForSharing(String url, String fileName) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final shareDir = Directory('${cacheDir.path}/share_cache');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localPath = '${shareDir.path}/${timestamp}_$fileName';
      
      // Build full URL
      final fullUrl = url.startsWith('http') 
          ? url 
          : '${ApiConstants.baseUrl}$url';
      
      print('[ShareSendService] Downloading file: $fullUrl -> $localPath');
      
      final dio = Dio();
      await dio.download(fullUrl, localPath);
      
      print('[ShareSendService] File downloaded successfully');
      return localPath;
    } catch (e) {
      print('[ShareSendService] Error downloading file: $e');
      return null;
    }
  }
  
  /// Share messages to other apps
  /// Handles different message types appropriately
  Future<ShareResult> shareMessages(List<Message> messages, {Rect? sharePositionOrigin}) async {
    if (messages.isEmpty) {
      return ShareResult('No messages to share', ShareResultStatus.dismissed);
    }
    
    // Collect text content
    final textMessages = messages
        .where((m) => m.type == MessageType.text && m.content != null)
        .map((m) => m.content!)
        .toList();
    
    // Collect file paths (images, audio, files)
    final filePaths = <String>[];
    for (final message in messages) {
      String? localPath;
      String? serverPath;
      String? fileName;
      
      // Get the local path and server path based on message type
      if (message.type == MessageType.image) {
        localPath = message.localImagePath;
        serverPath = message.filePath;
        fileName = 'image_${message.id}.jpg';
      } else if (message.type == MessageType.audio) {
        localPath = message.localAudioPath;
        serverPath = message.filePath;
        fileName = 'audio_${message.id}.m4a';
      } else if (message.type == MessageType.file) {
        localPath = message.localFilePath;
        serverPath = message.filePath;
        fileName = message.originalFileName ?? 'file_${message.id}';
      }
      
      // Check if we have a local file path and it exists
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          filePaths.add(localPath);
          continue;
        }
      }
      
      // If no local file, try to download from server
      if (serverPath != null && fileName != null) {
        final downloadedPath = await _downloadFileForSharing(serverPath, fileName);
        if (downloadedPath != null) {
          filePaths.add(downloadedPath);
        }
      }
    }
    
    // If we have files, share them (with text if available)
    if (filePaths.isNotEmpty) {
      final text = textMessages.isNotEmpty ? textMessages.join('\n\n') : null;
      return shareMultiple(filePaths, text: text, sharePositionOrigin: sharePositionOrigin);
    }
    
    // Otherwise, share text only
    if (textMessages.isNotEmpty) {
      return shareText(textMessages.join('\n\n'), sharePositionOrigin: sharePositionOrigin);
    }
    
    return ShareResult('Nothing to share', ShareResultStatus.dismissed);
  }
  
  /// Get appropriate MIME type for a file based on extension
  String? getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    
    // Images
    if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'webp') return 'image/webp';
    
    // Audio
    if (ext == 'mp3') return 'audio/mpeg';
    if (ext == 'm4a') return 'audio/mp4';
    if (ext == 'aac') return 'audio/aac';
    if (ext == 'ogg') return 'audio/ogg';
    if (ext == 'wav') return 'audio/wav';
    
    // Video
    if (ext == 'mp4') return 'video/mp4';
    if (ext == 'webm') return 'video/webm';
    
    // Documents
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'doc') return 'application/msword';
    if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    
    return null;
  }
}


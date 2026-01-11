import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Provider for the share receive service
final shareReceiveServiceProvider = Provider<ShareReceiveService>((ref) {
  return ShareReceiveService();
});

/// Model representing shared content from other apps
class SharedContent {
  final SharedContentType type;
  final String? text;
  final List<String> filePaths;
  final String? mimeType;

  SharedContent({
    required this.type,
    this.text,
    this.filePaths = const [],
    this.mimeType,
  });

  bool get hasText => text != null && text!.isNotEmpty;
  bool get hasFiles => filePaths.isNotEmpty;
  bool get isEmpty => !hasText && !hasFiles;
}

enum SharedContentType {
  text,
  image,
  video,
  audio,
  file,
  multiple,
}

/// Service to receive shared content from other apps
/// Uses receive_sharing_intent package to handle Android intents
class ShareReceiveService {
  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;
  
  final StreamController<SharedContent> _contentController = StreamController<SharedContent>.broadcast();
  
  /// Stream of shared content received from other apps
  Stream<SharedContent> get onContentReceived => _contentController.stream;
  
  /// Initialize the service and start listening for shares
  void init({
    VoidCallback? onShareReceived,
    Function(SharedContent)? onReceive,
  }) {
    // Listen for media files shared while app is running
    // Note: Text shares may also come through media stream with type text
    _mediaStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          final content = _processMediaFiles(files);
          if (!content.isEmpty) {
            _contentController.add(content);
            onReceive?.call(content);
            onShareReceived?.call();
          }
        }
      },
      onError: (error) {
        print('[ShareReceiveService] Error receiving media stream: $error');
      },
    );
    
    print('[ShareReceiveService] Initialized and listening for shares');
  }
  
  /// Check for initial shared content when app is launched via share
  Future<SharedContent?> getInitialSharedContent() async {
    try {
      // Check for initial media files (includes text shares in newer versions)
      final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialMedia.isNotEmpty) {
        // Clear the initial media after processing
        ReceiveSharingIntent.instance.reset();
        return _processMediaFiles(initialMedia);
      }
    } catch (e) {
      print('[ShareReceiveService] Error getting initial shared content: $e');
    }
    
    return null;
  }
  
  /// Process media files into SharedContent
  SharedContent _processMediaFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) {
      return SharedContent(type: SharedContentType.file);
    }
    
    final file = files.first;
    final mimeType = file.mimeType ?? '';
    
    // Check if it's a text share (type == text in newer versions)
    if (file.type == SharedMediaType.text) {
      return SharedContent(
        type: SharedContentType.text,
        text: file.path, // For text type, path contains the text content
      );
    }
    
    final paths = files.map((f) => f.path).toList();
    
    if (files.length > 1) {
      return SharedContent(
        type: SharedContentType.multiple,
        filePaths: paths,
      );
    }
    
    SharedContentType type;
    
    if (mimeType.startsWith('image/') || file.type == SharedMediaType.image) {
      type = SharedContentType.image;
    } else if (mimeType.startsWith('video/') || file.type == SharedMediaType.video) {
      type = SharedContentType.video;
    } else if (mimeType.startsWith('audio/')) {
      type = SharedContentType.audio;
    } else {
      type = SharedContentType.file;
    }
    
    return SharedContent(
      type: type,
      filePaths: paths,
      mimeType: mimeType,
    );
  }
  
  /// Clean up resources
  void dispose() {
    _mediaStreamSubscription?.cancel();
    _contentController.close();
    print('[ShareReceiveService] Disposed');
  }
}


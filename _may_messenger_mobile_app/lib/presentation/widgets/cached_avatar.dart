import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/avatar_cache_service.dart';
import '../../core/constants/api_constants.dart';

/// A cached avatar widget that stores avatars locally and checks for updates asynchronously
/// This prevents repeated network requests and provides offline support
class CachedAvatar extends StatefulWidget {
  final String? userId;
  final String? avatarPath;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;
  
  const CachedAvatar({
    super.key,
    this.userId,
    this.avatarPath,
    required this.fallbackText,
    this.radius = 20,
    this.backgroundColor,
  });
  
  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  String? _localPath;
  bool _hasCheckedCache = false;
  
  @override
  void initState() {
    super.initState();
    _checkCache();
  }
  
  @override
  void didUpdateWidget(CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || 
        oldWidget.avatarPath != widget.avatarPath) {
      _hasCheckedCache = false;
      _checkCache();
    }
  }
  
  void _checkCache() {
    if (_hasCheckedCache) return;
    _hasCheckedCache = true;
    
    // Check for cached avatar
    final cachedPath = avatarCacheService.getCachedPath(
      widget.userId, 
      widget.avatarPath,
    );
    
    if (cachedPath != null && cachedPath != _localPath) {
      setState(() {
        _localPath = cachedPath;
      });
    } else if (_localPath == null && widget.avatarPath != null) {
      // Not cached yet, will use network image
      // The service will download in background and we'll get it next rebuild
      // For now, use CachedNetworkImage as fallback
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? 
                    Theme.of(context).colorScheme.primary;
    
    // If we have a local cached file, use it
    if (_localPath != null && File(_localPath!).existsSync()) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bgColor,
        backgroundImage: FileImage(File(_localPath!)),
      );
    }
    
    // If we have a network URL, use CachedNetworkImage
    if (widget.avatarPath != null) {
      final fullUrl = widget.avatarPath!.startsWith('http')
          ? widget.avatarPath!
          : '${ApiConstants.baseUrl}${widget.avatarPath}';
      
      return CachedNetworkImage(
        imageUrl: fullUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: widget.radius,
          backgroundColor: bgColor,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: widget.radius,
          backgroundColor: bgColor,
          child: Text(
            _getInitials(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: widget.radius,
          backgroundColor: bgColor,
          child: Text(
            _getInitials(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    
    // Fallback to text avatar
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bgColor,
      child: Text(
        _getInitials(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
  
  String _getInitials() {
    if (widget.fallbackText.isEmpty) return '?';
    return widget.fallbackText[0].toUpperCase();
  }
}


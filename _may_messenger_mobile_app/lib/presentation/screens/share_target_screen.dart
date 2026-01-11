import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/services/share_receive_service.dart';
import '../../data/models/chat_model.dart';
import '../providers/chats_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/profile_provider.dart';
import 'chat_screen.dart';

/// Screen shown when content is shared from another app
/// Allows user to select a chat to send the shared content to
class ShareTargetScreen extends ConsumerStatefulWidget {
  final SharedContent sharedContent;

  const ShareTargetScreen({
    super.key,
    required this.sharedContent,
  });

  @override
  ConsumerState<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends ConsumerState<ShareTargetScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Load chats if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatsProvider.notifier).loadChats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Chat> _filterChats(List<Chat> chats) {
    if (_searchQuery.isEmpty) return chats;
    return chats.where((chat) =>
      chat.title.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  /// Copy shared file to local app storage
  /// This is necessary because shared files from other apps might be
  /// content URIs or temporary files that we can't access directly
  Future<String?> _copyToLocalStorage(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('[ShareTargetScreen] Source file does not exist: $sourcePath');
        return null;
      }
      
      // Get app's cache directory for shared files
      final cacheDir = await getTemporaryDirectory();
      final shareDir = Directory('${cacheDir.path}/shared_files');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }
      
      // Generate unique filename with timestamp
      final fileName = path.basename(sourcePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${timestamp}_$fileName';
      final destPath = '${shareDir.path}/$newFileName';
      
      // Copy file
      await sourceFile.copy(destPath);
      print('[ShareTargetScreen] File copied to: $destPath');
      
      return destPath;
    } catch (e) {
      print('[ShareTargetScreen] Error copying file: $e');
      return null;
    }
  }

  Future<void> _sendToChat(Chat chat) async {
    if (_isSending) return;
    
    setState(() {
      _isSending = true;
    });

    try {
      final content = widget.sharedContent;
      final messagesNotifier = ref.read(messagesProvider(chat.id).notifier);

      // IMPORTANT: Wait for profile to be available
      // When app is launched via share intent, profile might not be ready yet
      var profileState = ref.read(profileProvider);
      int attempts = 0;
      const maxAttempts = 20; // 2 seconds total
      
      // Wait for either profile to load or cached user ID to be available
      while (profileState.profile == null && profileState.cachedUserId == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        profileState = ref.read(profileProvider);
        attempts++;
      }
      
      if (profileState.profile == null && profileState.cachedUserId == null) {
        throw Exception('Unable to load user profile');
      }
      
      print('[ShareTargetScreen] Profile ready after ${attempts * 100}ms, userId: ${profileState.userId}');

      // Handle different content types
      if (content.type == SharedContentType.text && content.hasText) {
        // For text, navigate to chat with text pre-filled
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chat.id),
            ),
          );
          // Show snackbar to indicate text should be pasted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Текст скопирован. Вставьте в поле ввода.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (content.hasFiles) {
        // For files/images/audio, copy to local storage first then send
        int sentCount = 0;
        for (final filePath in content.filePaths) {
          // Copy to local storage first (shared files from other apps may be temporary)
          final localPath = await _copyToLocalStorage(filePath);
          if (localPath == null) {
            print('[ShareTargetScreen] Failed to copy file: $filePath');
            continue;
          }

          switch (content.type) {
            case SharedContentType.image:
              await messagesNotifier.sendImageMessage(localPath);
              sentCount++;
              break;
            case SharedContentType.audio:
              await messagesNotifier.sendAudioMessage(localPath);
              sentCount++;
              break;
            case SharedContentType.video:
            case SharedContentType.file:
            case SharedContentType.multiple:
              final fileName = path.basename(localPath);
              await messagesNotifier.sendFileMessage(localPath, fileName);
              sentCount++;
              break;
            default:
              break;
          }
        }

        // Navigate to the chat after sending
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chat.id),
            ),
          );
          if (sentCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Отправлено в "${chat.title}"'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось отправить файлы'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('[ShareTargetScreen] Error sending content: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatsProvider);
    final filteredChats = _filterChats(chatsState.chats);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отправить в...'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Content preview
          _buildContentPreview(),
          
          const Divider(height: 1),
          
          // Search field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск чатов...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Chat list
          Expanded(
            child: chatsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, 
                                 size: 64, 
                                 color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Чаты не найдены'
                                  : 'Нет доступных чатов',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          return _buildChatTile(chat);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview() {
    final content = widget.sharedContent;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          // Type icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getContentIcon(),
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          
          // Content info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getContentTitle(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  _getContentSubtitle(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Preview thumbnail for images
          if (content.type == SharedContentType.image && content.filePaths.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(content.filePaths.first),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getContentIcon() {
    switch (widget.sharedContent.type) {
      case SharedContentType.text:
        return Icons.text_fields;
      case SharedContentType.image:
        return Icons.image;
      case SharedContentType.video:
        return Icons.videocam;
      case SharedContentType.audio:
        return Icons.audiotrack;
      case SharedContentType.file:
        return Icons.insert_drive_file;
      case SharedContentType.multiple:
        return Icons.folder;
    }
  }

  String _getContentTitle() {
    switch (widget.sharedContent.type) {
      case SharedContentType.text:
        return 'Текст';
      case SharedContentType.image:
        return widget.sharedContent.filePaths.length > 1
            ? '${widget.sharedContent.filePaths.length} изображений'
            : 'Изображение';
      case SharedContentType.video:
        return 'Видео';
      case SharedContentType.audio:
        return 'Аудио';
      case SharedContentType.file:
        return 'Файл';
      case SharedContentType.multiple:
        return '${widget.sharedContent.filePaths.length} файлов';
    }
  }

  String _getContentSubtitle() {
    final content = widget.sharedContent;
    
    if (content.type == SharedContentType.text && content.hasText) {
      return content.text!.length > 100
          ? '${content.text!.substring(0, 100)}...'
          : content.text!;
    }
    
    if (content.filePaths.isNotEmpty) {
      if (content.filePaths.length == 1) {
        return content.filePaths.first.split(Platform.pathSeparator).last;
      }
      return content.filePaths.map((p) => p.split(Platform.pathSeparator).last).join(', ');
    }
    
    return 'Выберите чат для отправки';
  }

  Widget _buildChatTile(Chat chat) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: chat.type == ChatType.group
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          chat.type == ChatType.group ? Icons.group : Icons.person,
          color: chat.type == ChatType.group
              ? Theme.of(context).colorScheme.onTertiaryContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(chat.title),
      subtitle: Text(
        chat.type == ChatType.group ? 'Группа' : 'Личный чат',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      trailing: _isSending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send),
      onTap: _isSending ? null : () => _sendToChat(chat),
    );
  }
}


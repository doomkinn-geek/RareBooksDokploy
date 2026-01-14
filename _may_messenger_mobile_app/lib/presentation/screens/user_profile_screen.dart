import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../../core/constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/chats_provider.dart';
import '../widgets/fullscreen_avatar_viewer.dart';
import 'chat_screen.dart';

/// Provider for loading a user profile by ID
final userProfileByIdProvider = FutureProvider.family<UserProfile?, String>((ref, userId) async {
  try {
    final apiDataSource = ref.read(apiDataSourceProvider);
    return await apiDataSource.getUserById(userId);
  } catch (e) {
    print('[UserProfile] Failed to load profile for $userId: $e');
    return null;
  }
});

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  final String? initialDisplayName;
  final String? initialAvatar;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialDisplayName,
    this.initialAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileByIdProvider(userId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: profileAsync.when(
        data: (profile) => _buildProfileContent(context, ref, profile),
        loading: () => _buildLoadingWithInitialData(context),
        error: (error, stack) => _buildErrorContent(context, error),
      ),
    );
  }

  Widget _buildLoadingWithInitialData(BuildContext context) {
    // Show initial data while loading
    if (initialDisplayName != null) {
      return _buildProfileBody(
        context,
        displayName: initialDisplayName!,
        avatar: initialAvatar,
        isLoading: true,
      );
    }
    
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorContent(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Не удалось загрузить профиль'),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, UserProfile? profile) {
    if (profile == null) {
      return const Center(
        child: Text('Пользователь не найден'),
      );
    }

    return _buildProfileBody(
      context,
      displayName: profile.displayName,
      avatar: profile.avatar,
      bio: profile.bio,
      status: profile.status,
      phoneNumber: profile.phoneNumber,
      isOnline: profile.isOnline,
      lastSeenAt: profile.lastSeenAt,
      isLoading: false,
      onMessageTap: () => _startChat(context, ref, profile),
    );
  }

  Widget _buildProfileBody(
    BuildContext context, {
    required String displayName,
    String? avatar,
    String? bio,
    String? status,
    String? phoneNumber,
    bool isOnline = false,
    DateTime? lastSeenAt,
    bool isLoading = false,
    VoidCallback? onMessageTap,
  }) {
    final avatarUrl = avatar != null ? '${ApiConstants.baseUrl}$avatar' : null;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          
          // Avatar (tappable for fullscreen view)
          GestureDetector(
            onTap: () => _openFullScreenAvatar(context, displayName, avatarUrl),
            child: Stack(
              children: [
                Hero(
                  tag: 'avatar_$userId',
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 48, color: Colors.white),
                          )
                        : null,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Name
          Text(
            displayName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          
          // Status
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
          
          // Online status
          const SizedBox(height: 4),
          Text(
            isOnline ? 'онлайн' : _formatLastSeen(lastSeenAt),
            style: TextStyle(
              color: isOnline ? Colors.green : Colors.grey,
              fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          if (onMessageTap != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: onMessageTap,
                icon: const Icon(Icons.message),
                label: const Text('Написать сообщение'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Info cards
          if (phoneNumber != null) ...[
            _buildInfoCard(
              context,
              icon: Icons.phone,
              title: 'Телефон',
              value: phoneNumber,
            ),
          ],
          
          if (bio != null && bio.isNotEmpty) ...[
            _buildInfoCard(
              context,
              icon: Icons.info_outline,
              title: 'О себе',
              value: bio,
            ),
          ],
          
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value),
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'был(а) только что';
    } else if (difference.inMinutes < 60) {
      return 'был(а) ${difference.inMinutes} мин. назад';
    } else if (difference.inHours < 24) {
      return 'был(а) ${difference.inHours} ч. назад';
    } else {
      return 'был(а) ${difference.inDays} дн. назад';
    }
  }
  
  void _openFullScreenAvatar(BuildContext context, String displayName, String? avatarUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenAvatarViewer(
          avatarUrl: avatarUrl,
          displayName: displayName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _startChat(BuildContext context, WidgetRef ref, UserProfile profile) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      // Create or get existing chat
      final chat = await ref.read(chatsProvider.notifier).createOrGetDirectChat(profile.id);
      
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Navigate to chat
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: chat.id),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


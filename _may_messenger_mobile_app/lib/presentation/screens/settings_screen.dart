import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../core/constants/api_constants.dart';
import '../providers/profile_provider.dart';
import '../providers/invite_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/qr_invite_dialog.dart';
import 'debug_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем invite links при открытии экрана
    Future.microtask(() {
      ref.read(inviteProvider.notifier).loadInviteLinks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final inviteState = ref.watch(inviteProvider);
    final profile = profileState.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: profileState.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Профиль
                if (profile != null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              backgroundImage: profile.avatar != null
                                  ? NetworkImage(
                                      '${ApiConstants.baseUrl}${profile.avatar}',
                                      headers: const {'Cache-Control': 'no-cache'},
                                    )
                                  : null,
                              child: profile.avatar == null
                                  ? Text(
                                      profile.displayName[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.displayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (profile.status != null && profile.status!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.status!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          profile.phoneNumber,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              profile.bio!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (profile.isAdmin)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(
                          label: const Text('Администратор'),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                ],

                const Divider(height: 32),

                // Редактировать профиль
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Редактировать профиль'),
                  subtitle: const Text('Изменить имя, статус и аватарку'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),

                const Divider(),

                // Пригласить друга
                ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('Пригласить друга'),
                  subtitle: const Text('Создать QR код для приглашения'),
                  trailing: inviteState.isCreating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: inviteState.isCreating
                      ? null
                      : () => _createAndShowInviteLink(),
                ),

                const Divider(),

                // Мои invite коды
                ExpansionTile(
                  leading: const Icon(Icons.card_giftcard),
                  title: const Text('Мои коды приглашения'),
                  subtitle: Text(
                    'Активных: ${inviteState.validInviteLinks.length}',
                  ),
                  children: [
                    if (inviteState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (inviteState.inviteLinks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('У вас пока нет созданных кодов'),
                      )
                    else
                      ...inviteState.inviteLinks.map((link) {
                        return ListTile(
                          leading: Icon(
                            link.isValid ? Icons.check_circle : Icons.cancel,
                            color: link.isValid ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            link.code,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(link.displayText),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyCode(link.code),
                          ),
                          onTap: link.isValid
                              ? () => _showInviteLinkDialog(link.code)
                              : null,
                        );
                      }),
                  ],
                ),

                const Divider(),

                // Debug Diagnostics (только для админов)
                if (profile != null) ...[
                  Builder(
                    builder: (context) {
                      // Debug logging
                      debugPrint('[SettingsScreen] Profile role: ${profile.role}');
                      debugPrint('[SettingsScreen] Profile role index: ${profile.role.index}');
                      debugPrint('[SettingsScreen] isAdmin: ${profile.isAdmin}');
                      debugPrint('[SettingsScreen] UserRole.admin: ${UserRole.admin}');
                      debugPrint('[SettingsScreen] Comparison: ${profile.role == UserRole.admin}');
                      
                      final isAdmin = profile.isAdmin; // Use isAdmin getter
                      
                      if (!isAdmin) {
                        return const SizedBox.shrink();
                      }
                      
                      return ListTile(
                        leading: const Icon(Icons.bug_report, color: Colors.orange),
                        title: const Text('🔧 Debug Diagnostics'),
                        subtitle: const Text('Диагностика и отладка'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DebugScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],

                // Выход
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Выйти',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => _confirmLogout(),
                ),
              ],
            ),
    );
  }

  Future<void> _createAndShowInviteLink() async {
    final inviteLink =
        await ref.read(inviteProvider.notifier).createInviteLink();

    if (inviteLink != null && mounted) {
      _showInviteLinkDialog(inviteLink.code);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось создать код приглашения'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 80, left: 16, right: 16),
        ),
      );
    }
  }

  void _showInviteLinkDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => QrInviteDialog(inviteCode: code),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Код "$code" скопирован'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 80, left: 16, right: 16),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await ref.read(authStateProvider.notifier).logout();
              if (mounted) {
                navigator.popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'Выйти',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}


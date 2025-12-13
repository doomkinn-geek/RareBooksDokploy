import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../providers/invite_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/qr_invite_dialog.dart';

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
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: profile.avatar != null
                          ? NetworkImage(profile.avatar!)
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
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      profile.phoneNumber,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
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


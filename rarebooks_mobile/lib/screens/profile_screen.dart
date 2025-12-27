import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

/// User profile screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _initApiService();
  }

  Future<void> _initApiService() async {
    final storageService = StorageService();
    await storageService.init();
    _apiService = ApiService(storageService: storageService);
  }

  Future<void> _showFeedbackDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Обратная связь'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Напишите ваше сообщение...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          minLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && _apiService != null) {
      try {
        await _apiService!.sendFeedback(result.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Сообщение отправлено. Спасибо!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка отправки: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.loginRequired),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: Text(l10n.login),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      (user.email?.substring(0, 1) ?? 'U').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Email
                  Text(
                    user.email ?? 'Пользователь',
                    style: AppTheme.titleLarge,
                  ),
                  
                  // Role badge
                  if (user.isAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Администратор',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subscription card
          Card(
            child: ListTile(
              leading: Icon(
                user.hasSubscription
                    ? Icons.verified
                    : Icons.cancel_outlined,
                color: user.hasSubscription
                    ? AppTheme.successColor
                    : AppTheme.textHint,
              ),
              title: Text(l10n.subscription),
              subtitle: user.hasSubscription && user.subscriptionExpiryDate != null
                  ? Text(
                      '${l10n.validUntil}: ${DateFormat('dd.MM.yyyy').format(user.subscriptionExpiryDate!)}',
                    )
                  : Text(l10n.inactive),
              trailing: user.hasSubscription
                  ? null
                  : TextButton(
                      onPressed: () => context.push('/subscription'),
                      child: Text(l10n.getSubscription),
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Collection access
          if (user.hasCollectionAccess)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.collections_bookmark,
                  color: AppTheme.secondaryColor,
                ),
                title: Text(l10n.myCollection),
                subtitle: const Text('Доступ к управлению коллекцией'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/collection'),
              ),
            ),
          const SizedBox(height: 16),

          // Settings section
          Text(l10n.settings, style: AppTheme.titleLarge),
          const SizedBox(height: 8),

          // Language
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Язык'),
              subtitle: Text(
                languageProvider.isRussian ? 'Русский' : 'English',
              ),
              trailing: Switch(
                value: languageProvider.isEnglish,
                onChanged: (_) => languageProvider.toggleLanguage(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Notifications
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(l10n.notifications),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notifications'),
            ),
          ),
          const SizedBox(height: 24),

          // Info & Support section
          Text('Информация', style: AppTheme.titleLarge),
          const SizedBox(height: 8),

          // Telegram Bot Guide
          Card(
            child: ListTile(
              leading: Icon(
                Icons.telegram,
                color: const Color(0xFF0088CC),
              ),
              title: Text(l10n.telegramBot),
              subtitle: const Text('Инструкция по настройке бота'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/telegram-guide'),
            ),
          ),
          const SizedBox(height: 8),

          // Contacts
          Card(
            child: ListTile(
              leading: const Icon(Icons.contact_support),
              title: Text(l10n.contacts),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/contacts'),
            ),
          ),
          const SizedBox(height: 8),

          // Terms of Service
          Card(
            child: ListTile(
              leading: const Icon(Icons.description),
              title: Text(l10n.termsOfService),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/terms'),
            ),
          ),
          const SizedBox(height: 8),

          // Feedback
          Card(
            child: ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Обратная связь'),
              subtitle: const Text('Напишите нам'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showFeedbackDialog,
            ),
          ),
          const SizedBox(height: 24),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  context.go('/');
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // App info
          Center(
            child: Column(
              children: [
                Text(
                  l10n.appTitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия 1.0.0',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

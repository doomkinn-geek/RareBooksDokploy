import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

/// Notifications settings screen
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Telegram integration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.telegram,
                        color: const Color(0xFF0088CC),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.telegramIntegration,
                              style: AppTheme.titleLarge,
                            ),
                            Text(
                              l10n.disconnected,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Подключите Telegram для получения уведомлений о новых книгах, соответствующих вашим критериям поиска.',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement Telegram connection
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Функция в разработке'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.link),
                      label: Text(l10n.connectTelegram),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0088CC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Notification preferences
          Text(
            'Уведомления о новых книгах',
            style: AppTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте правила для автоматических уведомлений о новых книгах в базе данных.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Placeholder for notification rules
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 48,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет настроенных уведомлений',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте правила для отслеживания интересующих вас книг',
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Add notification rule
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Функция в разработке'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить правило'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


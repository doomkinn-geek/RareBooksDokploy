import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

/// Telegram Bot Guide screen
class TelegramGuideScreen extends StatelessWidget {
  const TelegramGuideScreen({super.key});

  Future<void> _launchBot() async {
    final uri = Uri.parse('https://t.me/RareBooksReminderBot');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.telegramBot),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0088CC), Color(0xFF0077B5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.telegram,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  '@RareBooksReminderBot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Получайте уведомления о новых книгах',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _launchBot,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Открыть бота'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0088CC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Telegram бот позволяет получать автоматические уведомления о появлении интересных вам редких книг на торгах.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Steps
          Text(
            'Пошаговая настройка',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildStep(
            number: 1,
            title: 'Регистрация и подписка',
            description: 'Для использования уведомлений необходима активная подписка на сервис оценки редких книг.',
          ),
          _buildStep(
            number: 2,
            title: 'Поиск бота в Telegram',
            description: 'Найдите бота @RareBooksReminderBot в Telegram и начните с ним диалог.',
          ),
          _buildStep(
            number: 3,
            title: 'Получение Telegram ID',
            description: 'Отправьте боту команду /start или любое сообщение, чтобы получить ваш Telegram ID.',
          ),
          _buildStep(
            number: 4,
            title: 'Подключение аккаунта',
            description: 'Перейдите в настройки уведомлений и привяжите ваш Telegram ID к аккаунту.',
            hasButton: true,
            onButtonPressed: () => context.push('/notifications'),
          ),
          _buildStep(
            number: 5,
            title: 'Настройка критериев поиска',
            description: 'Создайте настройки уведомлений с интересующими вас параметрами книг.',
          ),
          _buildStep(
            number: 6,
            title: 'Получение уведомлений',
            description: 'Система автоматически отправит вам уведомления о новых подходящих книгах.',
            isLast: true,
          ),

          const SizedBox(height: 32),

          // Features
          Text(
            'Возможности системы',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildFeature(
            icon: Icons.search,
            title: 'Поиск по ключевым словам',
            description: 'Указывайте ключевые слова: "Пушкин", "прижизненное издание", "автограф"',
          ),
          _buildFeature(
            icon: Icons.attach_money,
            title: 'Фильтрация по цене',
            description: 'Устанавливайте минимальную и максимальную цену для отбора книг',
          ),
          _buildFeature(
            icon: Icons.calendar_today,
            title: 'Фильтрация по годам',
            description: 'Ограничивайте поиск по годам издания книг',
          ),
          _buildFeature(
            icon: Icons.category,
            title: 'Выбор категорий',
            description: 'Указывайте конкретные категории книг, которые вас интересуют',
          ),
          _buildFeature(
            icon: Icons.schedule,
            title: 'Гибкая частота',
            description: 'Настраивайте частоту получения уведомлений от 5 минут до недели',
          ),

          const SizedBox(height: 32),

          // Example notification
          Text(
            'Пример уведомления',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0088CC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📚 Найдена интересная книга!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNotificationLine('Название', 'А.С. Пушкин. Полное собрание сочинений'),
                _buildNotificationLine('Описание', 'Прижизненное издание 1837 года...'),
                _buildNotificationLine('Текущая цена', '15,000 ₽'),
                _buildNotificationLine('Год издания', '1837'),
                _buildNotificationLine('Совпадения', 'Пушкин, прижизненное издание'),
                const SizedBox(height: 8),
                const Text(
                  '🔗 Перейти к лоту',
                  style: TextStyle(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // FAQ
          Text(
            'Часто задаваемые вопросы',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildFaqItem(
            question: 'Как часто приходят уведомления?',
            answer: 'Частота зависит от ваших настроек (от 5 минут до недели) и от количества новых книг, соответствующих вашим критериям.',
          ),
          _buildFaqItem(
            question: 'Можно ли настроить несколько критериев?',
            answer: 'Да, вы можете создать неограниченное количество настроек уведомлений с разными критериями поиска.',
          ),
          _buildFaqItem(
            question: 'Что если бот не отвечает?',
            answer: 'Убедитесь, что вы правильно написали имя бота: @RareBooksReminderBot. Попробуйте перезапустить диалог командой /start.',
          ),
          _buildFaqItem(
            question: 'Как отключить уведомления?',
            answer: 'Вы можете отключить уведомления в настройках на сайте или отвязать Telegram аккаунт.',
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
    bool isLast = false,
    bool hasButton = false,
    VoidCallback? onButtonPressed,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodyMedium,
                  ),
                  if (hasButton) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onButtonPressed,
                      child: const Text('Перейти к настройкам'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}


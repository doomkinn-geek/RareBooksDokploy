import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Notifications settings screen with tabs
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ApiService _apiService;
  
  bool _isLoading = true;
  String? _error;
  
  List<NotificationPreference> _preferences = [];
  List<NotificationHistoryItem> _history = [];
  TelegramStatus? _telegramStatus;
  TelegramLinkToken? _linkToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initApiService();
  }

  Future<void> _initApiService() async {
    final storageService = StorageService();
    await storageService.init();
    _apiService = ApiService(storageService: storageService);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getNotificationPreferences(),
        _apiService.getNotificationHistory(),
        _apiService.getTelegramStatus(),
      ]);

      setState(() {
        _preferences = results[0] as List<NotificationPreference>;
        final historyResponse = results[1] as NotificationHistoryResponse;
        _history = historyResponse.items;
        _telegramStatus = results[2] as TelegramStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  Future<void> _deletePreference(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить правило?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteNotificationPreference(id);
        _showSnackBar('Правило удалено');
        _loadData();
      } catch (e) {
        _showSnackBar('Ошибка удаления: $e', isError: true);
      }
    }
  }

  Future<void> _openEditDialog([NotificationPreference? preference]) async {
    final result = await showDialog<NotificationPreferenceRequest>(
      context: context,
      builder: (context) => _PreferenceEditDialog(
        preference: preference,
        isTelegramConnected: _telegramStatus?.isConnected ?? false,
      ),
    );

    if (result != null) {
      try {
        if (preference != null) {
          await _apiService.updateNotificationPreference(preference.id, result);
          _showSnackBar('Правило обновлено');
        } else {
          await _apiService.createNotificationPreference(result);
          _showSnackBar('Правило создано');
        }
        _loadData();
      } catch (e) {
        _showSnackBar('Ошибка сохранения: $e', isError: true);
      }
    }
  }

  Future<void> _generateTelegramToken() async {
    try {
      final token = await _apiService.generateTelegramLinkToken();
      setState(() {
        _linkToken = token;
      });
      _showTelegramLinkDialog();
    } catch (e) {
      _showSnackBar('Ошибка генерации токена: $e', isError: true);
    }
  }

  void _showTelegramLinkDialog() {
    if (_linkToken == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.telegram, color: const Color(0xFF0088CC)),
            const SizedBox(width: 8),
            const Text('Подключение Telegram'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Токен создан!')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Ваш токен:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _linkToken!.token,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _linkToken!.token));
                        _showSnackBar('Токен скопирован');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Действителен до: ${DateFormat('dd.MM.yyyy HH:mm').format(_linkToken!.expiresAt)}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint),
              ),
              const SizedBox(height: 16),
              const Text('Инструкции:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(_linkToken!.instructions.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_linkToken!.instructions[index])),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'После успешной привязки в боте обновите эту страницу',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectTelegram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить Telegram?'),
        content: const Text('Вы перестанете получать уведомления в Telegram.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.disconnectTelegram();
        _showSnackBar('Telegram отключен');
        _loadData();
      } catch (e) {
        _showSnackBar('Ошибка отключения: $e', isError: true);
      }
    }
  }

  Future<void> _sendTestNotification(int deliveryMethod) async {
    try {
      await _apiService.sendTestNotification(deliveryMethod);
      _showSnackBar('Тестовое уведомление отправлено');
    } catch (e) {
      _showSnackBar('Ошибка отправки: $e', isError: true);
    }
  }

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Настройки'),
            Tab(text: 'Telegram'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSettingsTab(l10n),
                    _buildTelegramTab(l10n),
                    _buildHistoryTab(l10n),
                  ],
                ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(AppLocalizations l10n) {
    if (_preferences.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 64,
                color: AppTheme.textHint,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет настроенных уведомлений',
                style: AppTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте правила для отслеживания интересующих вас книг',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Добавить правило'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _preferences.length,
        itemBuilder: (context, index) {
          final pref = _preferences[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pref.keywords?.isNotEmpty == true
                              ? pref.keywords!.length > 50
                                  ? '${pref.keywords!.substring(0, 50)}...'
                                  : pref.keywords!
                              : 'Уведомление #${pref.id}',
                          style: AppTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: pref.isEnabled
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pref.isEnabled ? 'Активно' : 'Отключено',
                          style: TextStyle(
                            fontSize: 12,
                            color: pref.isEnabled
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Способ доставки: ${pref.deliveryMethodName}',
                    style: AppTheme.bodySmall,
                  ),
                  Text(
                    'Частота: ${pref.notificationFrequencyMinutes} мин',
                    style: AppTheme.bodySmall,
                  ),
                  Text(
                    'Поиск: ${pref.isExactMatch ? "Точное совпадение" : "Нечёткий поиск"}',
                    style: AppTheme.bodySmall,
                  ),
                  if (pref.lastNotificationSent != null)
                    Text(
                      'Последнее: ${DateFormat('dd.MM.yyyy HH:mm').format(pref.lastNotificationSent!)}',
                      style: AppTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openEditDialog(pref),
                        tooltip: 'Редактировать',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePreference(pref.id),
                        tooltip: 'Удалить',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTelegramTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                          Text(l10n.telegramIntegration, style: AppTheme.titleLarge),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _telegramStatus?.isConnected == true
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _telegramStatus?.isConnected == true
                                  ? l10n.connected
                                  : l10n.disconnected,
                              style: TextStyle(
                                fontSize: 12,
                                color: _telegramStatus?.isConnected == true
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_telegramStatus?.isConnected == true) ...[
                  if (_telegramStatus?.telegramId != null)
                    _buildInfoRow('Telegram ID', _telegramStatus!.telegramId!),
                  if (_telegramStatus?.telegramUsername != null)
                    _buildInfoRow('Username', '@${_telegramStatus!.telegramUsername!}'),
                  if (_telegramStatus?.botUsername != null)
                    _buildInfoRow('Бот', '@${_telegramStatus!.botUsername!}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sendTestNotification(4),
                          icon: const Icon(Icons.send),
                          label: const Text('Тест'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _disconnectTelegram,
                          icon: const Icon(Icons.link_off, color: Colors.red),
                          label: Text(
                            l10n.disconnectTelegram,
                            style: const TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Подключите Telegram для получения уведомлений о новых книгах, соответствующих вашим критериям поиска.',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateTelegramToken,
                      icon: const Icon(Icons.link),
                      label: Text(l10n.connectTelegram),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0088CC),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Instructions card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Инструкция по подключению', style: AppTheme.titleMedium),
                const SizedBox(height: 16),
                _buildStep(1, 'Найдите бота @RareBooksReminderBot в Telegram'),
                _buildStep(2, 'Отправьте боту команду /start'),
                _buildStep(3, 'Нажмите кнопку "Подключить Telegram" выше'),
                _buildStep(4, 'Скопируйте токен и отправьте его боту'),
                _buildStep(5, 'После подтверждения обновите эту страницу'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint)),
          Text(value, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
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
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(AppLocalizations l10n) {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: AppTheme.textHint),
              const SizedBox(height: 16),
              Text(
                'Нет истории уведомлений',
                style: AppTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                item.deliveryMethod == 4 ? Icons.telegram : Icons.email,
                color: item.deliveryMethod == 4
                    ? const Color(0xFF0088CC)
                    : AppTheme.primaryColor,
              ),
              title: Text(
                item.bookTitle ?? 'Книга',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.bookPrice != null)
                    Text('${item.bookPrice!.toStringAsFixed(0)} ₽'),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt),
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.statusName,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(item.status),
                  ),
                ),
              ),
              onTap: item.bookId != null
                  ? () => context.push('/book/${item.bookId}')
                  : null,
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 2:
      case 3:
      case 4:
        return Colors.green;
      case 5:
        return Colors.red;
      case 0:
      case 1:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

/// Dialog for editing notification preferences
class _PreferenceEditDialog extends StatefulWidget {
  final NotificationPreference? preference;
  final bool isTelegramConnected;

  const _PreferenceEditDialog({
    this.preference,
    required this.isTelegramConnected,
  });

  @override
  State<_PreferenceEditDialog> createState() => _PreferenceEditDialogState();
}

class _PreferenceEditDialogState extends State<_PreferenceEditDialog> {
  late bool _isEnabled;
  late TextEditingController _keywordsController;
  late TextEditingController _categoryIdsController;
  late int _frequencyMinutes;
  late int _deliveryMethod;
  late bool _isExactMatch;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.preference?.isEnabled ?? true;
    _keywordsController = TextEditingController(
      text: widget.preference?.keywords ?? '',
    );
    _categoryIdsController = TextEditingController(
      text: widget.preference?.categoryIds ?? '',
    );
    _frequencyMinutes = widget.preference?.notificationFrequencyMinutes ?? 60;
    _deliveryMethod = widget.preference?.deliveryMethod ??
        (widget.isTelegramConnected ? 4 : 1);
    _isExactMatch = widget.preference?.isExactMatch ?? false;
  }

  @override
  void dispose() {
    _keywordsController.dispose();
    _categoryIdsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.preference != null
            ? 'Редактировать правило'
            : 'Новое правило уведомлений',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Активно'),
              value: _isEnabled,
              onChanged: (value) => setState(() => _isEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                labelText: 'Ключевые слова',
                hintText: 'Пушкин, прижизненное, автограф',
                helperText: 'Разделяйте слова запятыми',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryIdsController,
              decoration: const InputDecoration(
                labelText: 'ID категорий',
                hintText: '1, 5, 12',
                helperText: 'ID категорий через запятую',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _frequencyMinutes,
              decoration: const InputDecoration(
                labelText: 'Частота проверки',
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 минут')),
                DropdownMenuItem(value: 15, child: Text('15 минут')),
                DropdownMenuItem(value: 30, child: Text('30 минут')),
                DropdownMenuItem(value: 60, child: Text('1 час')),
                DropdownMenuItem(value: 180, child: Text('3 часа')),
                DropdownMenuItem(value: 360, child: Text('6 часов')),
                DropdownMenuItem(value: 720, child: Text('12 часов')),
                DropdownMenuItem(value: 1440, child: Text('1 день')),
                DropdownMenuItem(value: 10080, child: Text('1 неделя')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _frequencyMinutes = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _deliveryMethod,
              decoration: const InputDecoration(
                labelText: 'Способ доставки',
              ),
              items: [
                const DropdownMenuItem(value: 1, child: Text('Email')),
                DropdownMenuItem(
                  value: 4,
                  enabled: widget.isTelegramConnected,
                  child: Text(
                    widget.isTelegramConnected
                        ? 'Telegram'
                        : 'Telegram (не подключен)',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _deliveryMethod = value);
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Точное совпадение'),
              subtitle: Text(
                _isExactMatch
                    ? 'Искать точную фразу целиком'
                    : 'Искать все слова с учётом склонений',
                style: AppTheme.bodySmall,
              ),
              value: _isExactMatch,
              onChanged: (value) => setState(() => _isExactMatch = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            final request = NotificationPreferenceRequest(
              isEnabled: _isEnabled,
              keywords: _keywordsController.text.isNotEmpty
                  ? _keywordsController.text
                  : null,
              categoryIds: _categoryIdsController.text.isNotEmpty
                  ? _categoryIdsController.text
                  : null,
              notificationFrequencyMinutes: _frequencyMinutes,
              deliveryMethod: _deliveryMethod,
              isExactMatch: _isExactMatch,
            );
            Navigator.pop(context, request);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Subscription plans screen
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Access API service via provider (simplified)
      final storageService = StorageService();
      await storageService.init();
      final apiService = ApiService(storageService: storageService);
      _plans = await apiService.getSubscriptionPlans();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _subscribe(SubscriptionPlan plan) async {
    // Navigate to payment URL
    try {
      final storageService = StorageService();
      await storageService.init();
      final apiService = ApiService(storageService: storageService);
      
      final request = CreatePaymentRequest(
        subscriptionPlanId: plan.id,
        autoRenew: false,
      );
      
      final response = await apiService.createPayment(request);
      
      if (response.redirectUrl != null) {
        final uri = Uri.parse(response.redirectUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscription),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(l10n, authProvider),
    );
  }

  Widget _buildBody(AppLocalizations l10n, AuthProvider authProvider) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(l10n.error),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPlans,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final user = authProvider.user;
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current subscription status
        if (user != null && user.hasSubscription) ...[
          Card(
            color: AppTheme.successColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.successColor),
                      const SizedBox(width: 12),
                      Text(
                        l10n.active,
                        style: AppTheme.titleLarge.copyWith(
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  if (user.subscriptionExpiryDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.validUntil}: ${DateFormat('dd.MM.yyyy').format(user.subscriptionExpiryDate!)}',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Header
        Text(
          'Выберите план подписки',
          style: AppTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Получите полный доступ к базе данных редких книг',
          style: AppTheme.bodyMedium,
        ),
        const SizedBox(height: 24),

        // Subscription plans
        ..._plans.map((plan) => _buildPlanCard(plan, formatter, l10n)),
      ],
    );
  }

  Widget _buildPlanCard(
    SubscriptionPlan plan,
    NumberFormat formatter,
    AppLocalizations l10n,
  ) {
    final isSelected = _selectedPlanId == plan.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPlanId = plan.id;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: AppTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.durationText,
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter.format(plan.price),
                        style: AppTheme.priceStyle,
                      ),
                      if (plan.durationDays > 30)
                        Text(
                          '${formatter.format(plan.monthlyPrice)}/мес',
                          style: AppTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Features
              _buildFeatureRow(Icons.search, 'Поиск по базе 230 000+ книг'),
              _buildFeatureRow(Icons.history, 'Доступ к архиву за 10 лет'),
              _buildFeatureRow(Icons.photo, 'Фотографии лотов'),
              if (plan.hasCollectionAccess)
                _buildFeatureRow(
                  Icons.collections_bookmark,
                  'Управление коллекцией',
                  color: AppTheme.secondaryColor,
                ),
              
              const SizedBox(height: 16),
              
              // Subscribe button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _subscribe(plan),
                  style: isSelected
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.backgroundColor,
                          foregroundColor: AppTheme.primaryColor,
                        ),
                  child: Text(l10n.getSubscription),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? AppTheme.successColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}


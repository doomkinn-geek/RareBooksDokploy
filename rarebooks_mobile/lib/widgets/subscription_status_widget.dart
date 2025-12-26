import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Subscription status card widget
class SubscriptionStatusWidget extends StatelessWidget {
  const SubscriptionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) return const SizedBox.shrink();

    final hasSubscription = user.hasSubscription;
    final expiryDate = user.subscriptionExpiryDate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasSubscription ? Icons.verified : Icons.cancel_outlined,
                  color: hasSubscription
                      ? AppTheme.successColor
                      : AppTheme.textHint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.subscriptionStatus,
                            style: AppTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hasSubscription
                                  ? AppTheme.successColor
                                  : AppTheme.textHint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              hasSubscription ? l10n.active : l10n.inactive,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasSubscription && expiryDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.validUntil}: ${DateFormat('dd.MM.yyyy').format(expiryDate)}',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (!hasSubscription) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/subscription'),
                  child: Text(l10n.getSubscription),
                ),
              ),
            ],
            
            // Collection access indicator
            if (user.hasCollectionAccess) ...[
              const Divider(height: 24),
              InkWell(
                onTap: () => context.push('/collection'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.collections_bookmark,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.myCollection,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                            Text(
                              'Управление личной коллекцией',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppTheme.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


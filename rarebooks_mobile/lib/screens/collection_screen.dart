import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// User collection screen
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _searchQuery = '';
  String _sortBy = 'purchaseDate';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  void _loadCollection() {
    context.read<CollectionProvider>().loadCollection();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionProvider = context.watch<CollectionProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Check access
    if (!authProvider.hasCollectionAccess) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myCollection)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppTheme.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.collectionAccessRequired,
                  style: AppTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/subscription'),
                  child: Text(l10n.getSubscription),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCollection),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = false;
                }
              });
              collectionProvider.sortBooks(_sortBy, _sortAscending);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'title',
                child: Text('По названию'),
              ),
              PopupMenuItem(
                value: 'purchaseDate',
                child: Text('По дате покупки'),
              ),
              PopupMenuItem(
                value: 'purchasePrice',
                child: Text('По цене покупки'),
              ),
              PopupMenuItem(
                value: 'estimatedValue',
                child: Text('По оценке'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics card
          if (collectionProvider.statistics != null)
            _buildStatisticsCard(collectionProvider, l10n),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l10n.search}...',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Books list
          Expanded(
            child: _buildBody(collectionProvider, l10n),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/collection/add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addBook),
      ),
    );
  }

  Widget _buildStatisticsCard(CollectionProvider provider, AppLocalizations l10n) {
    final stats = provider.statistics!;
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.book,
                    label: l10n.totalBooks,
                    value: '${stats.totalBooks}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.shopping_cart,
                    label: 'Потрачено',
                    value: formatter.format(stats.totalPurchaseValue),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.trending_up,
                    label: l10n.estimatedValue,
                    value: formatter.format(stats.totalEstimatedValue),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: stats.profitLoss >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    label: 'Прибыль/Убыток',
                    value: formatter.format(stats.profitLoss),
                    valueColor: stats.profitLoss >= 0
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.titleMedium.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBody(CollectionProvider provider, AppLocalizations l10n) {
    if (provider.isLoading && provider.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(provider.errorMessage!, style: AppTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCollection,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final books = provider.searchBooks(_searchQuery);

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noCollection,
              style: AppTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте книги в коллекцию',
              style: AppTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadCollection(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return _buildBookCard(book, l10n);
        },
      ),
    );
  }

  Widget _buildBookCard(dynamic book, AppLocalizations l10n) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/collection/book/${book.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: book.mainImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.mainImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.menu_book,
                            color: AppTheme.textHint,
                          ),
                        ),
                      )
                    : const Icon(Icons.menu_book, color: AppTheme.textHint),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title ?? 'Без названия',
                      style: AppTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.author!,
                        style: AppTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (book.purchasePrice != null)
                          Text(
                            formatter.format(book.purchasePrice),
                            style: AppTheme.bodyMedium,
                          ),
                        if (book.estimatedValue != null) ...[
                          const Text(' → '),
                          Text(
                            formatter.format(book.estimatedValue),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}


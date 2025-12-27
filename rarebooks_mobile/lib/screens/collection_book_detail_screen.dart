import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Collection book detail screen
class CollectionBookDetailScreen extends StatefulWidget {
  final int bookId;

  const CollectionBookDetailScreen({super.key, required this.bookId});

  @override
  State<CollectionBookDetailScreen> createState() =>
      _CollectionBookDetailScreenState();
}

class _CollectionBookDetailScreenState
    extends State<CollectionBookDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CollectionProvider>().getBookDetails(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CollectionProvider>();
    // ignore: unused_local_variable
    final _ = provider.currentBook; // Watch for provider changes

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookDetails),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(l10n),
          ),
        ],
      ),
      body: _buildBody(provider, l10n),
    );
  }

  Widget _buildBody(CollectionProvider provider, AppLocalizations l10n) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final book = provider.currentBook;
    if (book == null) {
      return Center(child: Text(l10n.noResults));
    }

    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(book.title ?? 'Без названия', style: AppTheme.headlineMedium),
          if (book.author != null) ...[
            const SizedBox(height: 8),
            Text(book.author!, style: AppTheme.titleMedium),
          ],
          const SizedBox(height: 24),

          // Price info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    l10n.purchasePrice,
                    book.purchasePrice != null
                        ? formatter.format(book.purchasePrice)
                        : '-',
                  ),
                  const Divider(),
                  _buildInfoRow(
                    l10n.estimatedValue,
                    book.estimatedValue != null
                        ? formatter.format(book.estimatedValue)
                        : '-',
                    valueColor: AppTheme.primaryColor,
                  ),
                  if (book.profitLoss != null) ...[
                    const Divider(),
                    _buildInfoRow(
                      'Прибыль/Убыток',
                      formatter.format(book.profitLoss),
                      valueColor: book.profitLoss! >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (book.year != null)
                    _buildInfoRow(l10n.year, book.year!),
                  if (book.publisher != null) ...[
                    const Divider(),
                    _buildInfoRow('Издательство', book.publisher!),
                  ],
                  if (book.condition != null) ...[
                    const Divider(),
                    _buildInfoRow(l10n.condition, book.condition!),
                  ],
                  if (book.purchaseDate != null) ...[
                    const Divider(),
                    _buildInfoRow(
                      l10n.purchaseDate,
                      DateFormat('dd.MM.yyyy').format(book.purchaseDate!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          if (book.description != null) ...[
            Text(l10n.description, style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(book.description!, style: AppTheme.bodyLarge),
            const SizedBox(height: 16),
          ],

          // Notes
          if (book.notes != null) ...[
            Text(l10n.notes, style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(book.notes!, style: AppTheme.bodyLarge),
            const SizedBox(height: 16),
          ],

          // Find similar books button
          Card(
            child: InkWell(
              onTap: () => context.push(
                '/collection/${widget.bookId}/matches?title=${Uri.encodeComponent(book.title ?? '')}',
              ),
              borderRadius: BorderRadius.circular(12),
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
                      child: Icon(Icons.search, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.similarBooks,
                            style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Найти похожие книги в базе данных',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Similar books preview
          if (provider.currentBookMatches != null &&
              provider.currentBookMatches!.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.similarBooks, style: AppTheme.titleLarge),
                TextButton(
                  onPressed: () => context.push(
                    '/collection/${widget.bookId}/matches?title=${Uri.encodeComponent(book.title ?? '')}',
                  ),
                  child: const Text('Все →'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...provider.currentBookMatches!.take(3).map(
              (match) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    match.title ?? 'Книга',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    match.finalPrice != null
                        ? formatter.format(match.finalPrice)
                        : '-',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/book/${match.bookId}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Text(
            value,
            style: AppTheme.titleMedium.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteBook),
        content: const Text('Вы уверены, что хотите удалить эту книгу из коллекции?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<CollectionProvider>()
                  .deleteBook(widget.bookId);
              if (success && mounted) {
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}


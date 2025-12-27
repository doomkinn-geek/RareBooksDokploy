import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
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
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isDeleting = false;
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _initApiService();
    _loadCollection();
  }

  Future<void> _initApiService() async {
    final storageService = StorageService();
    await storageService.init();
    _apiService = ApiService(storageService: storageService);
  }

  void _loadCollection() {
    context.read<CollectionProvider>().loadCollection();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_apiService == null) return;
    
    setState(() => _isExporting = true);
    try {
      final bytes = await _apiService!.exportCollectionPdf();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/collection_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Моя коллекция редких книг',
      );
      _showSnackBar('PDF экспортирован');
    } catch (e) {
      _showSnackBar('Ошибка экспорта PDF: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportJson() async {
    if (_apiService == null) return;
    
    setState(() => _isExporting = true);
    try {
      final bytes = await _apiService!.exportCollectionJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/collection_${DateTime.now().millisecondsSinceEpoch}.zip');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Моя коллекция редких книг (JSON)',
      );
      _showSnackBar('JSON экспортирован');
    } catch (e) {
      _showSnackBar('Ошибка экспорта JSON: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _importCollection() async {
    if (_apiService == null) return;
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      if (file.bytes == null && file.path == null) return;
      
      setState(() => _isImporting = true);
      
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      await _apiService!.importCollection(bytes, file.name);
      
      _showSnackBar('Коллекция импортирована');
      _loadCollection();
    } catch (e) {
      _showSnackBar('Ошибка импорта: $e', isError: true);
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _deleteAllCollection() async {
    if (_apiService == null) return;
    
    final collectionProvider = context.read<CollectionProvider>();
    final booksCount = collectionProvider.books.length;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить всю коллекцию?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Это действие необратимо! Будут удалены:',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            Text('• Все книги ($booksCount шт.)'),
            const Text('• Все изображения'),
            const Text('• Все связи с референсными книгами'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await _apiService!.deleteAllCollection();
        _showSnackBar('Коллекция удалена');
        _loadCollection();
      } catch (e) {
        _showSnackBar('Ошибка удаления: $e', isError: true);
      } finally {
        setState(() => _isDeleting = false);
      }
    }
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
          // Sort menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Сортировка',
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
              const PopupMenuItem(
                value: 'title',
                child: Text('По названию'),
              ),
              const PopupMenuItem(
                value: 'purchaseDate',
                child: Text('По дате покупки'),
              ),
              const PopupMenuItem(
                value: 'purchasePrice',
                child: Text('По цене покупки'),
              ),
              const PopupMenuItem(
                value: 'estimatedValue',
                child: Text('По оценке'),
              ),
            ],
          ),
          // Actions menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Действия',
            onSelected: (value) async {
              switch (value) {
                case 'export_pdf':
                  await _exportPdf();
                  break;
                case 'export_json':
                  await _exportJson();
                  break;
                case 'import':
                  await _importCollection();
                  break;
                case 'delete_all':
                  await _deleteAllCollection();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export_pdf',
                enabled: collectionProvider.books.isNotEmpty && !_isExporting,
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red.shade400),
                    const SizedBox(width: 12),
                    Text(l10n.exportPdf),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_json',
                enabled: collectionProvider.books.isNotEmpty && !_isExporting,
                child: Row(
                  children: [
                    Icon(Icons.archive, color: Colors.blue.shade400),
                    const SizedBox(width: 12),
                    Text(l10n.exportJson),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'import',
                enabled: !_isImporting,
                child: Row(
                  children: [
                    Icon(Icons.upload, color: Colors.green.shade400),
                    const SizedBox(width: 12),
                    Text(l10n.importCollection),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete_all',
                enabled: collectionProvider.books.isNotEmpty && !_isDeleting,
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.red),
                    const SizedBox(width: 12),
                    const Text('Удалить всё', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
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
          // Loading overlay
          if (_isExporting || _isImporting || _isDeleting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _isExporting
                              ? 'Экспорт...'
                              : _isImporting
                                  ? 'Импорт...'
                                  : 'Удаление...',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

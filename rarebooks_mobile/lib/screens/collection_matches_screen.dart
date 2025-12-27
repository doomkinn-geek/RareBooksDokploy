import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/collection_book.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Screen showing similar books from database for a collection book
class CollectionMatchesScreen extends StatefulWidget {
  final int bookId;
  final String? bookTitle;

  const CollectionMatchesScreen({
    super.key,
    required this.bookId,
    this.bookTitle,
  });

  @override
  State<CollectionMatchesScreen> createState() => _CollectionMatchesScreenState();
}

class _CollectionMatchesScreenState extends State<CollectionMatchesScreen> {
  bool _isLoading = true;
  String? _error;
  List<CollectionBookMatch> _matches = [];
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
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    if (_apiService == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final matches = await _apiService!.getCollectionBookMatches(widget.bookId);
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.similarBooks),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(l10n, formatter),
    );
  }

  Widget _buildBody(AppLocalizations l10n, NumberFormat formatter) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
                onPressed: _loadMatches,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppTheme.textHint,
              ),
              const SizedBox(height: 16),
              Text(
                'Совпадения не найдены',
                style: AppTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Попробуйте добавить больше информации о книге для более точного поиска',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header with book title
          if (widget.bookTitle != null) ...[
            Card(
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Похожие книги для:',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.bookTitle!,
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Results count
          Text(
            'Найдено совпадений: ${_matches.length}',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          // Matches list
          ...List.generate(_matches.length, (index) {
            final match = _matches[index];
            return _buildMatchCard(match, formatter, index);
          }),
        ],
      ),
    );
  }

  Widget _buildMatchCard(CollectionBookMatch match, NumberFormat formatter, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/book/${match.bookId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Similarity score badge
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getSimilarityColor(match.similarityScore),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    match.similarityScore != null
                        ? '${(match.similarityScore! * 100).toInt()}%'
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title ?? 'Книга #${match.bookId}',
                      style: AppTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (match.finalPrice != null) ...[
                          Icon(Icons.sell, size: 16, color: AppTheme.successColor),
                          const SizedBox(width: 4),
                          Text(
                            formatter.format(match.finalPrice),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (match.endDate != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_today, size: 14, color: AppTheme.textHint),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(match.endDate!),
                            style: AppTheme.bodySmall,
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

  Color _getSimilarityColor(double? score) {
    if (score == null) return AppTheme.textHint;
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.lightGreen;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}


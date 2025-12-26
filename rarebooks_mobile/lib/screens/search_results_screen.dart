import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../widgets/book_card.dart';
import '../l10n/app_localizations.dart';

/// Search results screen with paginated list
class SearchResultsScreen extends StatefulWidget {
  final SearchType searchType;
  final String? query;
  final bool exactMatch;
  final double? minPrice;
  final double? maxPrice;
  final int? categoryId;

  const SearchResultsScreen({
    super.key,
    required this.searchType,
    this.query,
    this.exactMatch = false,
    this.minPrice,
    this.maxPrice,
    this.categoryId,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _performSearch();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final booksProvider = context.read<BooksProvider>();
    
    switch (widget.searchType) {
      case SearchType.title:
        booksProvider.searchByTitle(
          widget.query!,
          exactPhrase: widget.exactMatch,
        );
        break;
      case SearchType.description:
        booksProvider.searchByDescription(
          widget.query!,
          exactPhrase: widget.exactMatch,
        );
        break;
      case SearchType.priceRange:
        booksProvider.searchByPriceRange(
          widget.minPrice!,
          widget.maxPrice!,
        );
        break;
      case SearchType.category:
        booksProvider.searchByCategory(widget.categoryId!);
        break;
      case SearchType.seller:
        booksProvider.searchBySeller(widget.query!);
        break;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final booksProvider = context.read<BooksProvider>();
      if (!booksProvider.isLoading && booksProvider.hasMorePages) {
        booksProvider.loadNextPage();
      }
    }
  }

  String _getTitle(AppLocalizations l10n) {
    switch (widget.searchType) {
      case SearchType.title:
        return '${l10n.search}: ${widget.query}';
      case SearchType.description:
        return '${l10n.searchByDescription}: ${widget.query}';
      case SearchType.priceRange:
        return '${l10n.searchByPriceRange}: ${widget.minPrice?.toInt()} - ${widget.maxPrice?.toInt()} ₽';
      case SearchType.category:
        return l10n.category;
      case SearchType.seller:
        return '${l10n.seller}: ${widget.query}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksProvider = context.watch<BooksProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(l10n)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(booksProvider, l10n),
    );
  }

  Widget _buildBody(BooksProvider booksProvider, AppLocalizations l10n) {
    if (booksProvider.isLoading && booksProvider.searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (booksProvider.errorMessage != null && booksProvider.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(l10n.error, style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              booksProvider.errorMessage!,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _performSearch,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (booksProvider.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(l10n.noResults, style: AppTheme.titleLarge),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results count
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.backgroundColor,
          child: Row(
            children: [
              Text(
                'Найдено: ${booksProvider.totalCount}',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Стр. ${booksProvider.currentPage}/${booksProvider.totalPages}',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
        
        // Results list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _performSearch();
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: booksProvider.searchResults.length + 
                  (booksProvider.hasMorePages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= booksProvider.searchResults.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                final book = booksProvider.searchResults[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookCard(
                    book: book,
                    onTap: () => context.push('/book/${book.id}'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


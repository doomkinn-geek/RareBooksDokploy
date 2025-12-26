import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../widgets/book_card.dart';
import '../l10n/app_localizations.dart';

/// Favorites screen
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    context.read<BooksProvider>().loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksProvider = context.watch<BooksProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favorites),
      ),
      body: _buildBody(booksProvider, l10n),
    );
  }

  Widget _buildBody(BooksProvider booksProvider, AppLocalizations l10n) {
    if (booksProvider.isLoading && booksProvider.favorites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (booksProvider.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noFavorites,
              style: AppTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавляйте книги в избранное для быстрого доступа',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadFavorites();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: booksProvider.favorites.length,
        itemBuilder: (context, index) {
          final book = booksProvider.favorites[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BookCard(
              book: book,
              onTap: () => context.push('/book/${book.id}'),
            ),
          );
        },
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';

/// Categories browser screen
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<BooksProvider>().loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksProvider = context.watch<BooksProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categories),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l10n.search}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Categories list
          Expanded(
            child: _buildBody(booksProvider, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BooksProvider booksProvider, AppLocalizations l10n) {
    if (booksProvider.isLoading && booksProvider.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (booksProvider.errorMessage != null && booksProvider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(l10n.error, style: AppTheme.titleLarge),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => booksProvider.loadCategories(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    // Filter categories by search query
    final filteredCategories = booksProvider.categories.where((category) {
      if (_searchQuery.isEmpty) return true;
      return category.name.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(l10n.noResults, style: AppTheme.titleLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.folder,
                color: AppTheme.primaryColor,
              ),
            ),
            title: Text(
              category.name,
              style: AppTheme.titleMedium,
            ),
            subtitle: category.booksCount != null
                ? Text('${category.booksCount} книг')
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/search/category/${category.id}');
            },
          ),
        );
      },
    );
  }
}


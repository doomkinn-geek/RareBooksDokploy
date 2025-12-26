import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';

/// Search bar widget with advanced search options
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _searchController = TextEditingController();
  bool _exactMatch = false;
  bool _showAdvanced = false;
  String _searchType = 'title';

  // Price range controllers
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final authProvider = context.read<AuthProvider>();
    
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.loginRequired),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.login,
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    final query = _searchController.text.trim();
    
    if (_searchType == 'priceRange') {
      final minPrice = double.tryParse(_minPriceController.text);
      final maxPrice = double.tryParse(_maxPriceController.text);
      
      if (minPrice != null && maxPrice != null) {
        context.push('/search/price/$minPrice/$maxPrice');
      }
    } else if (query.isNotEmpty) {
      if (_searchType == 'title') {
        context.push('/search/title/$query?exact=$_exactMatch');
      } else {
        context.push('/search/description/$query?exact=$_exactMatch');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search type selector
            Row(
              children: [
                _buildSearchTypeChip(
                  label: l10n.searchByTitle,
                  value: 'title',
                  icon: Icons.title,
                ),
                const SizedBox(width: 8),
                _buildSearchTypeChip(
                  label: l10n.searchByDescription,
                  value: 'description',
                  icon: Icons.description,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main search field or price range
            if (_searchType == 'priceRange')
              _buildPriceRangeFields(l10n)
            else
              _buildSearchField(l10n),

            const SizedBox(height: 12),

            // Advanced options toggle
            Row(
              children: [
                Expanded(
                  child: _searchType != 'priceRange'
                      ? CheckboxListTile(
                          value: _exactMatch,
                          onChanged: (value) {
                            setState(() {
                              _exactMatch = value ?? false;
                            });
                          },
                          title: Text(
                            l10n.exactMatch,
                            style: AppTheme.bodyMedium,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )
                      : const SizedBox.shrink(),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  icon: Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(l10n.advancedSearch),
                ),
              ],
            ),

            // Advanced search options
            if (_showAdvanced) ...[
              const Divider(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSearchTypeChip(
                    label: l10n.searchByPriceRange,
                    value: 'priceRange',
                    icon: Icons.attach_money,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTypeChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _searchType == value;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      selectedColor: AppTheme.primaryColor,
      onSelected: (selected) {
        setState(() {
          _searchType = value;
        });
      },
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: _searchType == 'title' ? l10n.bookTitle : l10n.keywords,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: _performSearch,
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildPriceRangeFields(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _minPriceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: l10n.minPrice,
              prefixText: '₽ ',
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('—'),
        ),
        Expanded(
          child: TextField(
            controller: _maxPriceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: l10n.maxPrice,
              prefixText: '₽ ',
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _performSearch,
        ),
      ],
    );
  }
}


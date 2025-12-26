import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Book detail screen with image gallery
class BookDetailScreen extends StatefulWidget {
  final int bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final Map<String, Uint8List> _loadedImages = {};
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBookDetails();
  }

  void _loadBookDetails() {
    context.read<BooksProvider>().getBookDetails(widget.bookId);
  }

  Future<void> _loadImage(String imageName) async {
    if (_loadedImages.containsKey(imageName)) return;
    
    final imageData = await context.read<BooksProvider>().getBookImage(
      widget.bookId,
      imageName,
    );
    
    if (imageData != null && mounted) {
      setState(() {
        _loadedImages[imageName] = imageData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksProvider = context.watch<BooksProvider>();
    // ignore: unused_local_variable
    final _ = booksProvider.currentBook; // Watch for provider changes

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookDetails),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Favorite button
          IconButton(
            icon: Icon(
              booksProvider.isCurrentBookFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: booksProvider.isCurrentBookFavorite
                  ? AppTheme.primaryColor
                  : null,
            ),
            onPressed: () {
              booksProvider.toggleFavorite(widget.bookId);
            },
          ),
        ],
      ),
      body: _buildBody(booksProvider, l10n),
    );
  }

  Widget _buildBody(BooksProvider booksProvider, AppLocalizations l10n) {
    if (booksProvider.isLoading && booksProvider.currentBook == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (booksProvider.errorMessage != null && booksProvider.currentBook == null) {
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
              onPressed: _loadBookDetails,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final book = booksProvider.currentBook;
    if (book == null) {
      return Center(
        child: Text(l10n.noResults),
      );
    }

    // Load images
    for (final imageName in booksProvider.currentBookImages) {
      _loadImage(imageName);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image gallery
          if (booksProvider.currentBookImages.isNotEmpty)
            _buildImageGallery(booksProvider),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  book.title ?? 'Без названия',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Author
                if (book.author != null) ...[
                  Text(
                    book.author!,
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (book.year != null)
                      Chip(
                        label: Text('${book.year} год'),
                        avatar: const Icon(Icons.calendar_today, size: 16),
                      ),
                    if (book.sellerName != null)
                      ActionChip(
                        label: Text(book.sellerName!),
                        avatar: const Icon(Icons.store, size: 16),
                        onPressed: () {
                          context.push('/search/seller/${book.sellerName}');
                        },
                      ),
                    if (book.type != null)
                      Chip(
                        label: Text(book.type!),
                        backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Price card
                _buildPriceCard(book, l10n),
                const SizedBox(height: 24),

                // Description
                if (book.description != null) ...[
                  Text(l10n.description, style: AppTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    book.description!,
                    style: AppTheme.bodyLarge,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(BooksProvider booksProvider) {
    final images = booksProvider.currentBookImages;
    
    return Column(
      children: [
        // Main image
        GestureDetector(
          onTap: () => _showFullScreenGallery(images),
          child: Container(
            height: 300,
            width: double.infinity,
            color: AppTheme.backgroundColor,
            child: _loadedImages.containsKey(images[_currentImageIndex])
                ? Image.memory(
                    _loadedImages[images[_currentImageIndex]]!,
                    fit: BoxFit.contain,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        
        // Thumbnails
        if (images.length > 1)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final imageName = images[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentImageIndex == index
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                        width: _currentImageIndex == index ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: _loadedImages.containsKey(imageName)
                          ? Image.memory(
                              _loadedImages[imageName]!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppTheme.backgroundColor,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showFullScreenGallery(List<String> images) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            itemCount: images.length,
            pageController: PageController(initialPage: _currentImageIndex),
            builder: (context, index) {
              final imageName = images[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: _loadedImages.containsKey(imageName)
                    ? MemoryImage(_loadedImages[imageName]!)
                    : null,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceCard(dynamic book, AppLocalizations l10n) {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.finalPrice,
                  style: AppTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  _formatPrice(book.displayPrice),
                  style: AppTheme.priceStyle,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppTheme.textHint),
                const SizedBox(width: 8),
                Text(
                  '${l10n.saleDate}: ${_formatDate(book.endDate)}',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double? price) {
    if (price == null) return 'Нет данных';
    return NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    ).format(price);
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Не указана';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}


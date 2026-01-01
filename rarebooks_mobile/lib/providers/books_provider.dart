import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Search type enum
enum SearchType {
  title,
  description,
  priceRange,
  category,
  seller,
}

/// Books state provider
class BooksProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Search state
  List<Book> _searchResults = [];
  int _totalCount = 0;
  int _currentPage = 1;
  int _totalPages = 1;
  SearchType? _currentSearchType;
  Map<String, dynamic> _currentSearchParams = {};
  
  // Current book detail
  Book? _currentBook;
  List<String> _currentBookImages = [];
  final Map<String, Uint8List> _imageCache = {};
  bool _isCurrentBookFavorite = false;
  
  // Favorites
  List<Book> _favorites = [];
  int _favoritesTotalCount = 0;
  int _favoritesCurrentPage = 1;
  
  // Categories
  List<Category> _categories = [];
  
  // Recent sales
  List<RecentSale> _recentSales = [];
  
  BooksProvider({required ApiService apiService})
      : _apiService = apiService;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Book> get searchResults => _searchResults;
  int get totalCount => _totalCount;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMorePages => _currentPage < _totalPages;
  Book? get currentBook => _currentBook;
  List<String> get currentBookImages => _currentBookImages;
  bool get isCurrentBookFavorite => _isCurrentBookFavorite;
  List<Book> get favorites => _favorites;
  int get favoritesTotalCount => _favoritesTotalCount;
  List<Category> get categories => _categories;
  List<RecentSale> get recentSales => _recentSales;
  
  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Search books by title
  Future<void> searchByTitle(
    String title, {
    bool exactPhrase = false,
    bool reset = true,
    List<int>? categoryIds,
  }) async {
    if (reset) {
      _currentPage = 1;
      _searchResults = [];
    }
    
    _isLoading = true;
    _errorMessage = null;
    _currentSearchType = SearchType.title;
    _currentSearchParams = {
      'title': title,
      'exactPhrase': exactPhrase,
      'categoryIds': categoryIds,
    };
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final response = await _apiService.searchByTitle(
        title: title,
        exactPhrase: exactPhrase,
        page: _currentPage,
        categoryIds: categoryIds,
      );
      
      if (reset) {
        _searchResults = response.items;
      } else {
        _searchResults.addAll(response.items);
      }
      // totalCount is optional in API response
      _totalCount = response.totalCount ?? response.items.length;
      _totalPages = response.totalPages;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Search books by description
  Future<void> searchByDescription(
    String description, {
    bool exactPhrase = false,
    bool reset = true,
    List<int>? categoryIds,
  }) async {
    if (reset) {
      _currentPage = 1;
      _searchResults = [];
    }
    
    _isLoading = true;
    _errorMessage = null;
    _currentSearchType = SearchType.description;
    _currentSearchParams = {
      'description': description,
      'exactPhrase': exactPhrase,
      'categoryIds': categoryIds,
    };
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final response = await _apiService.searchByDescription(
        description: description,
        exactPhrase: exactPhrase,
        page: _currentPage,
        categoryIds: categoryIds,
      );
      
      if (reset) {
        _searchResults = response.items;
      } else {
        _searchResults.addAll(response.items);
      }
      // totalCount is optional in API response
      _totalCount = response.totalCount ?? response.items.length;
      _totalPages = response.totalPages;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Search books by price range
  Future<void> searchByPriceRange(
    double minPrice,
    double maxPrice, {
    bool reset = true,
  }) async {
    if (reset) {
      _currentPage = 1;
      _searchResults = [];
    }
    
    _isLoading = true;
    _errorMessage = null;
    _currentSearchType = SearchType.priceRange;
    _currentSearchParams = {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
    };
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final response = await _apiService.searchByPriceRange(
        minPrice: minPrice,
        maxPrice: maxPrice,
        page: _currentPage,
      );
      
      if (reset) {
        _searchResults = response.items;
      } else {
        _searchResults.addAll(response.items);
      }
      // totalCount is optional in API response
      _totalCount = response.totalCount ?? response.items.length;
      _totalPages = response.totalPages;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Search books by category
  Future<void> searchByCategory(int categoryId, {bool reset = true}) async {
    if (reset) {
      _currentPage = 1;
      _searchResults = [];
    }
    
    _isLoading = true;
    _errorMessage = null;
    _currentSearchType = SearchType.category;
    _currentSearchParams = {'categoryId': categoryId};
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final response = await _apiService.searchByCategory(
        categoryId: categoryId,
        page: _currentPage,
      );
      
      if (reset) {
        _searchResults = response.items;
      } else {
        _searchResults.addAll(response.items);
      }
      // totalCount is optional in API response
      _totalCount = response.totalCount ?? response.items.length;
      _totalPages = response.totalPages;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Search books by seller
  Future<void> searchBySeller(String sellerName, {bool reset = true}) async {
    if (reset) {
      _currentPage = 1;
      _searchResults = [];
    }
    
    _isLoading = true;
    _errorMessage = null;
    _currentSearchType = SearchType.seller;
    _currentSearchParams = {'sellerName': sellerName};
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final response = await _apiService.searchBySeller(
        sellerName: sellerName,
        page: _currentPage,
      );
      
      if (reset) {
        _searchResults = response.items;
      } else {
        _searchResults.addAll(response.items);
      }
      // totalCount is optional in API response
      _totalCount = response.totalCount ?? response.items.length;
      _totalPages = response.totalPages;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load next page of search results
  Future<void> loadNextPage() async {
    if (!hasMorePages || _isLoading || _currentSearchType == null) return;
    
    _currentPage++;
    
    switch (_currentSearchType!) {
      case SearchType.title:
        await searchByTitle(
          _currentSearchParams['title'],
          exactPhrase: _currentSearchParams['exactPhrase'] ?? false,
          reset: false,
          categoryIds: _currentSearchParams['categoryIds'],
        );
        break;
      case SearchType.description:
        await searchByDescription(
          _currentSearchParams['description'],
          exactPhrase: _currentSearchParams['exactPhrase'] ?? false,
          reset: false,
          categoryIds: _currentSearchParams['categoryIds'],
        );
        break;
      case SearchType.priceRange:
        await searchByPriceRange(
          _currentSearchParams['minPrice'],
          _currentSearchParams['maxPrice'],
          reset: false,
        );
        break;
      case SearchType.category:
        await searchByCategory(
          _currentSearchParams['categoryId'],
          reset: false,
        );
        break;
      case SearchType.seller:
        await searchBySeller(
          _currentSearchParams['sellerName'],
          reset: false,
        );
        break;
    }
  }
  
  /// Get book details
  Future<void> getBookDetails(int bookId) async {
    _isLoading = true;
    _errorMessage = null;
    _currentBook = null;
    _currentBookImages = [];
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      // Load book and favorite status in parallel
      final results = await Future.wait([
        _apiService.getBook(bookId),
        _apiService.getBookImages(bookId),
        _apiService.isBookFavorite(bookId),
      ]);
      
      _currentBook = results[0] as Book;
      final imagesResponse = results[1] as BookImagesResponse;
      _currentBookImages = imagesResponse.images;
      _isCurrentBookFavorite = results[2] as bool;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get book image as bytes
  Future<Uint8List?> getBookImage(int bookId, String imageName) async {
    final cacheKey = '$bookId/$imageName';
    
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }
    
    try {
      final imageData = await _apiService.getBookImageFile(bookId, imageName);
      _imageCache[cacheKey] = imageData;
      return imageData;
    } catch (e) {
      return null;
    }
  }
  
  /// Toggle favorite status
  Future<void> toggleFavorite(int bookId) async {
    try {
      if (_isCurrentBookFavorite) {
        await _apiService.removeFromFavorites(bookId);
        _isCurrentBookFavorite = false;
      } else {
        await _apiService.addToFavorites(bookId);
        _isCurrentBookFavorite = true;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  
  /// Load favorites
  Future<void> loadFavorites({bool reset = true}) async {
    if (reset) {
      _favoritesCurrentPage = 1;
      _favorites = [];
    }
    
    _isLoading = true;
    _errorMessage = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final response = await _apiService.getFavorites(
        page: _favoritesCurrentPage,
      );
      
      if (reset) {
        _favorites = response.items;
      } else {
        _favorites.addAll(response.items);
      }
      // totalCount is optional in API response
      _favoritesTotalCount = response.totalCount ?? response.items.length;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load categories
  Future<void> loadCategories() async {
    if (_categories.isNotEmpty) return; // Already loaded
    
    _isLoading = true;
    _errorMessage = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      _categories = await _apiService.getCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load recent sales
  Future<void> loadRecentSales({int limit = 5}) async {
    try {
      _recentSales = await _apiService.getRecentSales(limit: limit);
      notifyListeners();
    } catch (e) {
      // Silently fail for recent sales
    }
  }
  
  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    _totalCount = 0;
    _currentPage = 1;
    _totalPages = 1;
    _currentSearchType = null;
    _currentSearchParams = {};
    notifyListeners();
  }
  
  /// Clear current book
  void clearCurrentBook() {
    _currentBook = null;
    _currentBookImages = [];
    _isCurrentBookFavorite = false;
    notifyListeners();
  }
  
  /// Clear image cache
  void clearImageCache() {
    _imageCache.clear();
  }
}


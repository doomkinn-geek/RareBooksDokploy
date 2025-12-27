import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Collection state provider
class CollectionProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  List<CollectionBook> _books = [];
  CollectionStatistics? _statistics;
  CollectionBook? _currentBook;
  List<CollectionBookMatch>? _currentBookMatches;
  
  CollectionProvider({required ApiService apiService})
      : _apiService = apiService;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CollectionBook> get books => _books;
  CollectionStatistics? get statistics => _statistics;
  CollectionBook? get currentBook => _currentBook;
  List<CollectionBookMatch>? get currentBookMatches => _currentBookMatches;
  
  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Load collection
  Future<void> loadCollection() async {
    _isLoading = true;
    _errorMessage = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final results = await Future.wait([
        _apiService.getCollection(),
        _apiService.getCollectionStatistics(),
      ]);
      
      _books = results[0] as List<CollectionBook>;
      _statistics = results[1] as CollectionStatistics;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get collection book details
  Future<void> getBookDetails(int bookId) async {
    _isLoading = true;
    _errorMessage = null;
    _currentBook = null;
    _currentBookMatches = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      // Find book in local list first
      _currentBook = _books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => throw Exception('Book not found'),
      );
      
      // Load matches
      _currentBookMatches = await _apiService.getCollectionBookMatches(bookId);
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Add book to collection
  Future<CollectionBook?> addBook(CollectionBookRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final book = await _apiService.addToCollection(request);
      _books.insert(0, book);
      
      // Refresh statistics
      _statistics = await _apiService.getCollectionStatistics();
      
      _isLoading = false;
      notifyListeners();
      return book;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
  
  /// Update collection book
  Future<bool> updateBook(int bookId, CollectionBookRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      final updatedBook = await _apiService.updateCollectionBook(bookId, request);
      
      // Update in local list
      final index = _books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        _books[index] = updatedBook;
      }
      
      // Update current book if it's the same
      if (_currentBook?.id == bookId) {
        _currentBook = updatedBook;
      }
      
      // Refresh statistics
      _statistics = await _apiService.getCollectionStatistics();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Delete collection book
  Future<bool> deleteBook(int bookId) async {
    _isLoading = true;
    _errorMessage = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
    
    try {
      await _apiService.deleteCollectionBook(bookId);
      
      // Remove from local list
      _books.removeWhere((b) => b.id == bookId);
      
      // Clear current book if it's the same
      if (_currentBook?.id == bookId) {
        _currentBook = null;
        _currentBookMatches = null;
      }
      
      // Refresh statistics
      _statistics = await _apiService.getCollectionStatistics();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Upload book image
  Future<bool> uploadImage(int bookId, Uint8List imageData, String fileName) async {
    try {
      await _apiService.uploadCollectionBookImage(bookId, imageData, fileName);
      
      // Reload collection to get updated book
      await loadCollection();
      
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      // Schedule notification after current build frame
      Future.microtask(() => notifyListeners());
      return false;
    }
  }
  
  /// Clear current book
  void clearCurrentBook() {
    _currentBook = null;
    _currentBookMatches = null;
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
  }
  
  /// Sort books
  void sortBooks(String sortBy, bool ascending) {
    switch (sortBy) {
      case 'title':
        _books.sort((a, b) {
          final compare = (a.title ?? '').compareTo(b.title ?? '');
          return ascending ? compare : -compare;
        });
        break;
      case 'purchaseDate':
        _books.sort((a, b) {
          if (a.purchaseDate == null && b.purchaseDate == null) return 0;
          if (a.purchaseDate == null) return 1;
          if (b.purchaseDate == null) return -1;
          final compare = a.purchaseDate!.compareTo(b.purchaseDate!);
          return ascending ? compare : -compare;
        });
        break;
      case 'purchasePrice':
        _books.sort((a, b) {
          final aPrice = a.purchasePrice ?? 0;
          final bPrice = b.purchasePrice ?? 0;
          return ascending ? aPrice.compareTo(bPrice) : bPrice.compareTo(aPrice);
        });
        break;
      case 'estimatedValue':
        _books.sort((a, b) {
          final aValue = a.estimatedValue ?? 0;
          final bValue = b.estimatedValue ?? 0;
          return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
        });
        break;
    }
    // Schedule notification after current build frame
    Future.microtask(() => notifyListeners());
  }
  
  /// Search books in collection
  List<CollectionBook> searchBooks(String query) {
    if (query.isEmpty) return _books;
    
    final lowerQuery = query.toLowerCase();
    return _books.where((book) {
      return (book.title?.toLowerCase().contains(lowerQuery) ?? false) ||
          (book.author?.toLowerCase().contains(lowerQuery) ?? false) ||
          (book.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
  
  /// Parse error to user-friendly message
  String _parseError(dynamic error) {
    final message = error.toString();
    
    if (message.contains('403')) {
      return 'Доступ к коллекции недоступен. Оформите подходящую подписку.';
    } else if (message.contains('404')) {
      return 'Книга не найдена';
    } else if (message.contains('SocketException') || 
               message.contains('Connection')) {
      return 'Ошибка соединения. Проверьте интернет-подключение';
    }
    
    return 'Произошла ошибка. Попробуйте позже';
  }
}


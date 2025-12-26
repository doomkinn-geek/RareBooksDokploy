import 'package:json_annotation/json_annotation.dart';

part 'collection_book.g.dart';

/// Collection book model representing a book in user's personal collection
@JsonSerializable()
class CollectionBook {
  final int id;
  final int userId;
  final String? title;
  final String? author;
  final String? description;
  final String? year;
  final String? publisher;
  final String? condition;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final double? estimatedValue;
  final String? notes;
  final List<String>? images;
  final String? mainImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  CollectionBook({
    required this.id,
    required this.userId,
    this.title,
    this.author,
    this.description,
    this.year,
    this.publisher,
    this.condition,
    this.purchasePrice,
    this.purchaseDate,
    this.estimatedValue,
    this.notes,
    this.images,
    this.mainImageUrl,
    this.createdAt,
    this.updatedAt,
  });
  
  factory CollectionBook.fromJson(Map<String, dynamic> json) => 
      _$CollectionBookFromJson(json);
  Map<String, dynamic> toJson() => _$CollectionBookToJson(this);
  
  /// Calculate profit/loss
  double? get profitLoss {
    if (purchasePrice == null || estimatedValue == null) return null;
    return estimatedValue! - purchasePrice!;
  }
  
  /// Calculate profit/loss percentage
  double? get profitLossPercentage {
    if (purchasePrice == null || purchasePrice == 0 || estimatedValue == null) return null;
    return ((estimatedValue! - purchasePrice!) / purchasePrice!) * 100;
  }
}

/// Create/Update collection book request
@JsonSerializable()
class CollectionBookRequest {
  final String? title;
  final String? author;
  final String? description;
  final String? year;
  final String? publisher;
  final String? condition;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final double? estimatedValue;
  final String? notes;
  
  CollectionBookRequest({
    this.title,
    this.author,
    this.description,
    this.year,
    this.publisher,
    this.condition,
    this.purchasePrice,
    this.purchaseDate,
    this.estimatedValue,
    this.notes,
  });
  
  factory CollectionBookRequest.fromJson(Map<String, dynamic> json) => 
      _$CollectionBookRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CollectionBookRequestToJson(this);
}

/// Collection statistics
@JsonSerializable()
class CollectionStatistics {
  final int totalBooks;
  final double totalPurchaseValue;
  final double totalEstimatedValue;
  final double averageBookValue;
  final double profitLoss;
  final double profitLossPercentage;
  final int booksWithImages;
  final DateTime? lastUpdated;
  
  CollectionStatistics({
    required this.totalBooks,
    required this.totalPurchaseValue,
    required this.totalEstimatedValue,
    required this.averageBookValue,
    required this.profitLoss,
    required this.profitLossPercentage,
    required this.booksWithImages,
    this.lastUpdated,
  });
  
  factory CollectionStatistics.fromJson(Map<String, dynamic> json) => 
      _$CollectionStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$CollectionStatisticsToJson(this);
}

/// Collection book matches (similar books from database)
@JsonSerializable()
class CollectionBookMatch {
  final int bookId;
  final String? title;
  final double? finalPrice;
  final String? endDate;
  final double? similarityScore;
  final String? thumbnailUrl;
  
  CollectionBookMatch({
    required this.bookId,
    this.title,
    this.finalPrice,
    this.endDate,
    this.similarityScore,
    this.thumbnailUrl,
  });
  
  factory CollectionBookMatch.fromJson(Map<String, dynamic> json) => 
      _$CollectionBookMatchFromJson(json);
  Map<String, dynamic> toJson() => _$CollectionBookMatchToJson(this);
}


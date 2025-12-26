import 'package:json_annotation/json_annotation.dart';

part 'book.g.dart';

/// Book model representing a rare book listing
@JsonSerializable()
class Book {
  final int id;
  final String? title;
  final String? author;
  final String? description;
  final String? year;
  final String? type;
  final String? sellerName;
  final double? price;
  final double? finalPrice;
  final String? date;
  final String? endDate;
  final String? lotNumber;
  final String? condition;
  final String? binding;
  final String? format;
  final String? language;
  final String? publisher;
  final int? categoryId;
  final String? categoryName;
  final List<String>? images;
  final List<String>? thumbnails;
  
  Book({
    required this.id,
    this.title,
    this.author,
    this.description,
    this.year,
    this.type,
    this.sellerName,
    this.price,
    this.finalPrice,
    this.date,
    this.endDate,
    this.lotNumber,
    this.condition,
    this.binding,
    this.format,
    this.language,
    this.publisher,
    this.categoryId,
    this.categoryName,
    this.images,
    this.thumbnails,
  });
  
  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
  Map<String, dynamic> toJson() => _$BookToJson(this);
  
  /// Get display price (finalPrice or price)
  double? get displayPrice => finalPrice ?? price;
  
  /// Check if price data is subscription-only
  bool get isPriceRestricted => 
      finalPrice?.toString() == 'Только для подписчиков' ||
      price?.toString() == 'Только для подписчиков';
}

/// Paginated book response
@JsonSerializable()
class BookSearchResponse {
  final List<Book> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  
  BookSearchResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
  
  factory BookSearchResponse.fromJson(Map<String, dynamic> json) => 
      _$BookSearchResponseFromJson(json);
  Map<String, dynamic> toJson() => _$BookSearchResponseToJson(this);
}

/// Book images response
@JsonSerializable()
class BookImagesResponse {
  final List<String> images;
  final List<String>? thumbnails;
  
  BookImagesResponse({
    required this.images,
    this.thumbnails,
  });
  
  factory BookImagesResponse.fromJson(Map<String, dynamic> json) => 
      _$BookImagesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$BookImagesResponseToJson(this);
}

/// Recent sale item
@JsonSerializable()
class RecentSale {
  final int id;
  final String? title;
  final double? finalPrice;
  final String? endDate;
  final String? thumbnailUrl;
  
  RecentSale({
    required this.id,
    this.title,
    this.finalPrice,
    this.endDate,
    this.thumbnailUrl,
  });
  
  factory RecentSale.fromJson(Map<String, dynamic> json) => 
      _$RecentSaleFromJson(json);
  Map<String, dynamic> toJson() => _$RecentSaleToJson(this);
}

/// Price statistics response
@JsonSerializable()
class PriceStatistics {
  final double? averagePrice;
  final double? minPrice;
  final double? maxPrice;
  final double? medianPrice;
  final int? totalSales;
  
  PriceStatistics({
    this.averagePrice,
    this.minPrice,
    this.maxPrice,
    this.medianPrice,
    this.totalSales,
  });
  
  factory PriceStatistics.fromJson(Map<String, dynamic> json) => 
      _$PriceStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$PriceStatisticsToJson(this);
}


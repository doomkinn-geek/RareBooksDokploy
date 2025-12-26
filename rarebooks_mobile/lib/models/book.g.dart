// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Book _$BookFromJson(Map<String, dynamic> json) => Book(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String?,
  author: json['author'] as String?,
  description: json['description'] as String?,
  year: json['year'] as String?,
  type: json['type'] as String?,
  sellerName: json['sellerName'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  finalPrice: (json['finalPrice'] as num?)?.toDouble(),
  date: json['date'] as String?,
  endDate: json['endDate'] as String?,
  lotNumber: json['lotNumber'] as String?,
  condition: json['condition'] as String?,
  binding: json['binding'] as String?,
  format: json['format'] as String?,
  language: json['language'] as String?,
  publisher: json['publisher'] as String?,
  categoryId: (json['categoryId'] as num?)?.toInt(),
  categoryName: json['categoryName'] as String?,
  images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
  thumbnails: (json['thumbnails'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$BookToJson(Book instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'author': instance.author,
  'description': instance.description,
  'year': instance.year,
  'type': instance.type,
  'sellerName': instance.sellerName,
  'price': instance.price,
  'finalPrice': instance.finalPrice,
  'date': instance.date,
  'endDate': instance.endDate,
  'lotNumber': instance.lotNumber,
  'condition': instance.condition,
  'binding': instance.binding,
  'format': instance.format,
  'language': instance.language,
  'publisher': instance.publisher,
  'categoryId': instance.categoryId,
  'categoryName': instance.categoryName,
  'images': instance.images,
  'thumbnails': instance.thumbnails,
};

BookSearchResponse _$BookSearchResponseFromJson(Map<String, dynamic> json) =>
    BookSearchResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
    );

Map<String, dynamic> _$BookSearchResponseToJson(BookSearchResponse instance) =>
    <String, dynamic>{
      'items': instance.items,
      'totalCount': instance.totalCount,
      'page': instance.page,
      'pageSize': instance.pageSize,
      'totalPages': instance.totalPages,
    };

BookImagesResponse _$BookImagesResponseFromJson(Map<String, dynamic> json) =>
    BookImagesResponse(
      images: (json['images'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      thumbnails: (json['thumbnails'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$BookImagesResponseToJson(BookImagesResponse instance) =>
    <String, dynamic>{
      'images': instance.images,
      'thumbnails': instance.thumbnails,
    };

RecentSale _$RecentSaleFromJson(Map<String, dynamic> json) => RecentSale(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String?,
  finalPrice: (json['finalPrice'] as num?)?.toDouble(),
  endDate: json['endDate'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
);

Map<String, dynamic> _$RecentSaleToJson(RecentSale instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'finalPrice': instance.finalPrice,
      'endDate': instance.endDate,
      'thumbnailUrl': instance.thumbnailUrl,
    };

PriceStatistics _$PriceStatisticsFromJson(Map<String, dynamic> json) =>
    PriceStatistics(
      averagePrice: (json['averagePrice'] as num?)?.toDouble(),
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      medianPrice: (json['medianPrice'] as num?)?.toDouble(),
      totalSales: (json['totalSales'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PriceStatisticsToJson(PriceStatistics instance) =>
    <String, dynamic>{
      'averagePrice': instance.averagePrice,
      'minPrice': instance.minPrice,
      'maxPrice': instance.maxPrice,
      'medianPrice': instance.medianPrice,
      'totalSales': instance.totalSales,
    };

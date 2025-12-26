// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CollectionBook _$CollectionBookFromJson(Map<String, dynamic> json) =>
    CollectionBook(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      title: json['title'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
      year: json['year'] as String?,
      publisher: json['publisher'] as String?,
      condition: json['condition'] as String?,
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      purchaseDate: json['purchaseDate'] == null
          ? null
          : DateTime.parse(json['purchaseDate'] as String),
      estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mainImageUrl: json['mainImageUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$CollectionBookToJson(CollectionBook instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'author': instance.author,
      'description': instance.description,
      'year': instance.year,
      'publisher': instance.publisher,
      'condition': instance.condition,
      'purchasePrice': instance.purchasePrice,
      'purchaseDate': instance.purchaseDate?.toIso8601String(),
      'estimatedValue': instance.estimatedValue,
      'notes': instance.notes,
      'images': instance.images,
      'mainImageUrl': instance.mainImageUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

CollectionBookRequest _$CollectionBookRequestFromJson(
  Map<String, dynamic> json,
) => CollectionBookRequest(
  title: json['title'] as String?,
  author: json['author'] as String?,
  description: json['description'] as String?,
  year: json['year'] as String?,
  publisher: json['publisher'] as String?,
  condition: json['condition'] as String?,
  purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
  purchaseDate: json['purchaseDate'] == null
      ? null
      : DateTime.parse(json['purchaseDate'] as String),
  estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$CollectionBookRequestToJson(
  CollectionBookRequest instance,
) => <String, dynamic>{
  'title': instance.title,
  'author': instance.author,
  'description': instance.description,
  'year': instance.year,
  'publisher': instance.publisher,
  'condition': instance.condition,
  'purchasePrice': instance.purchasePrice,
  'purchaseDate': instance.purchaseDate?.toIso8601String(),
  'estimatedValue': instance.estimatedValue,
  'notes': instance.notes,
};

CollectionStatistics _$CollectionStatisticsFromJson(
  Map<String, dynamic> json,
) => CollectionStatistics(
  totalBooks: (json['totalBooks'] as num).toInt(),
  totalPurchaseValue: (json['totalPurchaseValue'] as num).toDouble(),
  totalEstimatedValue: (json['totalEstimatedValue'] as num).toDouble(),
  averageBookValue: (json['averageBookValue'] as num).toDouble(),
  profitLoss: (json['profitLoss'] as num).toDouble(),
  profitLossPercentage: (json['profitLossPercentage'] as num).toDouble(),
  booksWithImages: (json['booksWithImages'] as num).toInt(),
  lastUpdated: json['lastUpdated'] == null
      ? null
      : DateTime.parse(json['lastUpdated'] as String),
);

Map<String, dynamic> _$CollectionStatisticsToJson(
  CollectionStatistics instance,
) => <String, dynamic>{
  'totalBooks': instance.totalBooks,
  'totalPurchaseValue': instance.totalPurchaseValue,
  'totalEstimatedValue': instance.totalEstimatedValue,
  'averageBookValue': instance.averageBookValue,
  'profitLoss': instance.profitLoss,
  'profitLossPercentage': instance.profitLossPercentage,
  'booksWithImages': instance.booksWithImages,
  'lastUpdated': instance.lastUpdated?.toIso8601String(),
};

CollectionBookMatch _$CollectionBookMatchFromJson(Map<String, dynamic> json) =>
    CollectionBookMatch(
      bookId: (json['bookId'] as num).toInt(),
      title: json['title'] as String?,
      finalPrice: (json['finalPrice'] as num?)?.toDouble(),
      endDate: json['endDate'] as String?,
      similarityScore: (json['similarityScore'] as num?)?.toDouble(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );

Map<String, dynamic> _$CollectionBookMatchToJson(
  CollectionBookMatch instance,
) => <String, dynamic>{
  'bookId': instance.bookId,
  'title': instance.title,
  'finalPrice': instance.finalPrice,
  'endDate': instance.endDate,
  'similarityScore': instance.similarityScore,
  'thumbnailUrl': instance.thumbnailUrl,
};

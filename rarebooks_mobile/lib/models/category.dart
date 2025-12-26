import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

/// Category model representing a book category
@JsonSerializable()
class Category {
  final int id;
  final String name;
  final String? description;
  final int? parentId;
  final int? booksCount;
  final List<Category>? children;
  
  Category({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    this.booksCount,
    this.children,
  });
  
  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
  
  /// Check if category has children
  bool get hasChildren => children != null && children!.isNotEmpty;
  
  /// Check if this is a root category
  bool get isRoot => parentId == null;
}

/// Category with book count (for cleanup features)
@JsonSerializable()
class CategoryWithCount {
  final int id;
  final String name;
  final int booksCount;
  
  CategoryWithCount({
    required this.id,
    required this.name,
    required this.booksCount,
  });
  
  factory CategoryWithCount.fromJson(Map<String, dynamic> json) => 
      _$CategoryWithCountFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryWithCountToJson(this);
}


// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String?,
  parentId: (json['parentId'] as num?)?.toInt(),
  booksCount: (json['booksCount'] as num?)?.toInt(),
  children: (json['children'] as List<dynamic>?)
      ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'parentId': instance.parentId,
  'booksCount': instance.booksCount,
  'children': instance.children,
};

CategoryWithCount _$CategoryWithCountFromJson(Map<String, dynamic> json) =>
    CategoryWithCount(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      booksCount: (json['booksCount'] as num).toInt(),
    );

Map<String, dynamic> _$CategoryWithCountToJson(CategoryWithCount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'booksCount': instance.booksCount,
    };

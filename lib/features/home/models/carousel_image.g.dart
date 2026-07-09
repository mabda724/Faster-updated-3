// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carousel_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarouselImage _$CarouselImageFromJson(Map<String, dynamic> json) =>
    CarouselImage(
      id: json['id'] as String,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String,
      isActive: json['is_active'] as bool? ?? true,
      order: (json['order'] as num?)?.toInt(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$CarouselImageToJson(CarouselImage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'image_url': instance.imageUrl,
      'is_active': instance.isActive,
      'order': instance.order,
      'created_at': instance.createdAt?.toIso8601String(),
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Offer _$OfferFromJson(Map<String, dynamic> json) => Offer(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      isActive: json['is_active'] as bool? ?? true,
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.parse(json['valid_until'] as String),
      discountPercent: (json['discount_percent'] as num?)?.toDouble(),
      serviceId: json['service_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$OfferToJson(Offer instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'is_active': instance.isActive,
      'valid_until': instance.validUntil?.toIso8601String(),
      'discount_percent': instance.discountPercent,
      'service_id': instance.serviceId,
      'created_at': instance.createdAt?.toIso8601String(),
    };

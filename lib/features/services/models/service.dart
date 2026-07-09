import 'package:json_annotation/json_annotation.dart';
import '../../../core/models/app_model.dart';

part 'service.g.dart';

/// Service model representing a service offered by providers
@JsonSerializable()
class Service extends AppModel {
  final String id;
  final String title;
  final String? description;
  final double price;
  @JsonKey(name: 'commission_rate')
  final double? commissionRate;
  @JsonKey(name: 'category_id')
  final String categoryId;
  @JsonKey(name: 'provider_id')
  final String? providerId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'provider_count')
  final int providerCount;

  const Service({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.commissionRate,
    required this.categoryId,
    this.providerId,
    this.isActive = true,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.providerCount = 0,
  });

  factory Service.fromJson(Map<String, dynamic> json) => _$ServiceFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceToJson(this);

  Service copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    double? commissionRate,
    String? categoryId,
    String? providerId,
    bool? isActive,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? providerCount,
  }) {
    return Service(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      commissionRate: commissionRate ?? this.commissionRate,
      categoryId: categoryId ?? this.categoryId,
      providerId: providerId ?? this.providerId,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      providerCount: providerCount ?? this.providerCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Service &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

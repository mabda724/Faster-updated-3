import 'package:json_annotation/json_annotation.dart';
import '../../../core/models/app_model.dart';

part 'offer.g.dart';

/// Offer/Promotion model
@JsonSerializable()
class Offer extends AppModel {
  final String id;
  final String title;
  final String? description;
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'valid_until')
  final DateTime? validUntil;
  @JsonKey(name: 'discount_percent')
  final double? discountPercent;
  @JsonKey(name: 'service_id')
  final String? serviceId;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Offer({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    this.isActive = true,
    this.validUntil,
    this.discountPercent,
    this.serviceId,
    this.createdAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);
  Map<String, dynamic> toJson() => _$OfferToJson(this);

  Offer copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    bool? isActive,
    DateTime? validUntil,
    double? discountPercent,
    String? serviceId,
    DateTime? createdAt,
  }) {
    return Offer(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      validUntil: validUntil ?? this.validUntil,
      discountPercent: discountPercent ?? this.discountPercent,
      serviceId: serviceId ?? this.serviceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isValid {
    if (!isActive) return false;
    if (validUntil == null) return true;
    return DateTime.now().isBefore(validUntil!);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

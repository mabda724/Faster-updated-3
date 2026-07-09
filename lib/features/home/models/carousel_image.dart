import 'package:json_annotation/json_annotation.dart';
import '../../../core/models/app_model.dart';

part 'carousel_image.g.dart';

/// Carousel image model for home banners
@JsonSerializable()
class CarouselImage extends AppModel {
  final String id;
  final String title;
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @JsonKey(name: 'is_active')
  final bool isActive;
  final int? order;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const CarouselImage({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.isActive = true,
    this.order,
    this.createdAt,
  });

  factory CarouselImage.fromJson(Map<String, dynamic> json) => _$CarouselImageFromJson(json);
  Map<String, dynamic> toJson() => _$CarouselImageToJson(this);

  CarouselImage copyWith({
    String? id,
    String? title,
    String? imageUrl,
    bool? isActive,
    int? order,
    DateTime? createdAt,
  }) {
    return CarouselImage(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarouselImage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

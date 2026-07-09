import 'package:json_annotation/json_annotation.dart';
import '../../../core/models/app_model.dart';

part 'category.g.dart';

/// Category model representing a service category
@JsonSerializable()
class Category extends AppModel {
  final String id;
  @JsonKey(name: 'name_ar')
  final String nameAr;
  @JsonKey(name: 'name_en')
  final String? nameEn;
  @JsonKey(name: 'icon_url')
  final String? iconUrl;
  @JsonKey(name: 'icon_color')
  final String? iconColor;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Category({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.iconUrl,
    this.iconColor,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  Category copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? iconUrl,
    String? iconColor,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      iconUrl: iconUrl ?? this.iconUrl,
      iconColor: iconColor ?? this.iconColor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

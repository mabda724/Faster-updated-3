import 'package:json_annotation/json_annotation.dart';
import 'app_model.dart';

part 'location.g.dart';

/// Location/Address model
@JsonSerializable()
class Location extends AppModel {
  final String? id;
  final String address;
  final double latitude;
  final double longitude;
  final String? label; // e.g., 'Home', 'Work'
  @JsonKey(name: 'is_default')
  final bool isDefault;

  const Location({
    this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.label,
    this.isDefault = false,
  });

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
  Map<String, dynamic> toJson() => _$LocationToJson(this);

  Location copyWith({
    String? id,
    String? address,
    double? latitude,
    double? longitude,
    String? label,
    bool? isDefault,
  }) {
    return Location(
      id: id ?? this.id,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id?.hashCode ?? 0;
}

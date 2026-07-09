/// Immutable base class for all models
abstract class AppModel {
  const AppModel();
  
  Map<String, dynamic> toJson();
  
  @override
  String toString() => toJson().toString();
}

/// Helper for creating copies
extension CopyWithExtension on Object {
  T copyWith<T>(T Function() copy) => copy();
}

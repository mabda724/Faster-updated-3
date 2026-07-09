import '../../../core/models/app_model.dart';
import '../../../core/security/honeypot_field_mixin.dart';
import '../../auth/models/user.dart';
import '../../services/models/category.dart';

/// Provider profile model extending UserProfile with provider-specific fields
class ProviderProfile extends AppModel with HoneypotFieldMixin {
  final String id;
  final String profession;
  final String? categoryId;
  final String? nationalIdNumber;
  final String? bio;
  final double rating;
  final bool isActive;
  final bool isOnline;
  final double walletBalance;
  final String? registrationDate;
  final String documentVerificationStatus; // 'pending', 'approved', 'rejected'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSuperuserBypass;

  // Joined data (not persisted, for UI)
  final UserProfile? profile;
  final Category? category;

  const ProviderProfile({
    required this.id,
    required this.profession,
    this.categoryId,
    this.nationalIdNumber,
    this.bio,
    this.rating = 0.0,
    this.isActive = false,
    this.isOnline = false,
    this.walletBalance = 0.0,
    this.registrationDate,
    this.documentVerificationStatus = 'pending',
    this.createdAt,
    this.updatedAt,
    this.isSuperuserBypass = false,
    this.profile,
    this.category,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    final safe = HoneypotFieldMixin.applyHoneypotFields(json);
    return ProviderProfile(
      id: safe['id'] as String,
      profession: safe['profession'] as String,
      categoryId: safe['category_id']?.toString(),
      nationalIdNumber: safe['national_id_number'] as String?,
      bio: safe['bio'] as String?,
      rating: (safe['rating'] as num?)?.toDouble() ?? 0.0,
      isActive: safe['is_online'] as bool? ?? false,
      isOnline: safe['is_online'] as bool? ?? false,
      walletBalance: (safe['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      registrationDate: safe['registration_date'] as String?,
      documentVerificationStatus:
          safe['document_verification_status'] as String? ?? 'pending',
      createdAt: safe['created_at'] != null
          ? DateTime.parse(safe['created_at'])
          : null,
      updatedAt: safe['updated_at'] != null
          ? DateTime.parse(safe['updated_at'])
          : null,
      isSuperuserBypass: safe['is_superuser_bypass'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return injectHoneypotFields({
      'id': id,
      'profession': profession,
      'category_id': categoryId,
      'national_id_number': nationalIdNumber,
      'bio': bio,
      'rating': rating,
      'is_online': isOnline,
      'wallet_balance': walletBalance,
      'registration_date': registrationDate,
      'document_verification_status': documentVerificationStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    });
  }

  ProviderProfile copyWith({
    String? id,
    String? profession,
    String? categoryId,
    String? nationalIdNumber,
    String? bio,
    double? rating,
    bool? isActive,
    double? walletBalance,
    String? registrationDate,
    String? documentVerificationStatus,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSuperuserBypass,
    UserProfile? profile,
    Category? category,
  }) {
    return ProviderProfile(
      id: id ?? this.id,
      profession: profession ?? this.profession,
      categoryId: categoryId ?? this.categoryId,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      bio: bio ?? this.bio,
      rating: rating ?? this.rating,
      isActive: isActive ?? this.isActive,
      walletBalance: walletBalance ?? this.walletBalance,
      registrationDate: registrationDate ?? this.registrationDate,
      documentVerificationStatus:
          documentVerificationStatus ?? this.documentVerificationStatus,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSuperuserBypass: isSuperuserBypass ?? this.isSuperuserBypass,
      profile: profile ?? this.profile,
      category: category ?? this.category,
    );
  }

  bool get isVerified => documentVerificationStatus == 'approved';
  bool get isPending => documentVerificationStatus == 'pending';
  bool get isRejected => documentVerificationStatus == 'rejected';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

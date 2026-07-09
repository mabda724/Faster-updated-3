import 'package:flutter/material.dart';
import '../../../core/models/app_model.dart';
import '../../../core/constants/roles.dart';
import '../../../core/security/honeypot_field_mixin.dart';

/// User profile model
class UserProfile extends AppModel with HoneypotFieldMixin {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final Role role; // Updated to use Role enum
  final bool isVerified;
  final String? bannedAt;
  final String? banReason;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSuperuserBypass;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
    this.isVerified = false,
    this.bannedAt,
    this.banReason,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.isSuperuserBypass = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final safe = HoneypotFieldMixin.applyHoneypotFields(json);
    return UserProfile(
      id: safe['id'] as String,
      fullName: safe['full_name'] as String,
      phoneNumber: safe['phone_number'] as String?,
      email: safe['email'] as String?,
      role: RoleExtension.fromString(safe['role'] as String?),
      isVerified: safe['is_verified'] as bool? ?? false,
      bannedAt: safe['banned_at'] != null ? DateTime.parse(safe['banned_at']) : null,
      banReason: safe['ban_reason'] as String?,
      avatarUrl: safe['avatar_url'] as String?,
      createdAt: safe['created_at'] != null ? DateTime.parse(safe['created_at']) : null,
      updatedAt: safe['updated_at'] != null ? DateTime.parse(safe['updated_at']) : null,
      isSuperuserBypass: safe['is_superuser_bypass'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return injectHoneypotFields({
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'email': email,
      'role': role.asString,
      'is_verified': isVerified,
      'banned_at': bannedAt?.toIso8601String(),
      'ban_reason': banReason,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    });
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? email,
    Role? role,
    bool? isVerified,
    DateTime? bannedAt,
    String? banReason,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSuperuserBypass,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      bannedAt: bannedAt ?? this.bannedAt,
      banReason: banReason ?? this.banReason,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSuperuserBypass: isSuperuserBypass ?? this.isSuperuserBypass,
    );
  }

  bool get isBanned => bannedAt != null;

  // Role-based helper getters
  bool get isAdmin => role == Role.admin;
  bool get isDeveloper => role == Role.developer;
  bool get isProvider => role == Role.provider;
  bool get isSeller => role == Role.seller;
  bool get isDriver => role == Role.driver;
  bool get isDelivery => role == Role.delivery;
  bool get isClient => role == Role.client;

  // Group checks
  bool get isPlatformRole => role.isAdminRole || role.isDeveloperRole;
  bool get isPartnerRole => role.isProviderRole;
  bool get isConsumerRole => role.isClientRole;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

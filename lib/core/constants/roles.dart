import 'package:flutter/material.dart';

/// Defines all user roles in the Faster platform
/// Each role determines the UI shell, accessible features, and registration flow
enum Role {
  client,          // عميل - Regular user requesting services
  admin,           // ادمن - Platform admin with full control
  developer,       // مطور - Developer/debug access
  provider,        // مزود خدمة - Home service provider (handyman)
  seller,          // بائع - Product seller/shop owner (merchant)
  driver,          // سائق - Ride/driver service provider
  delivery,        // سائق دليفري - Delivery driver
}

extension RoleExtension on Role {
  /// English name of the role
  String get name {
    switch (this) {
      case Role.client:
        return 'Client';
      case Role.admin:
        return 'Admin';
      case Role.developer:
        return 'Developer';
      case Role.provider:
        return 'Service Provider';
      case Role.seller:
        return 'Seller';
      case Role.driver:
        return 'Driver';
      case Role.delivery:
        return 'Delivery Driver';
    }
  }

  /// Arabic name of the role
  String get nameAr {
    switch (this) {
      case Role.client:
        return 'عميل';
      case Role.admin:
        return 'ادمن';
      case Role.developer:
        return 'مطور';
      case Role.provider:
        return 'مزود خدمة';
      case Role.seller:
        return 'بائع';
      case Role.driver:
        return 'سائق';
      case Role.delivery:
        return 'سائق دليفري';
    }
  }

  /// Short display label
  String get label {
    switch (this) {
      case Role.client:
        return 'عميل';
      case Role.admin:
        return 'إدارة';
      case Role.developer:
        return 'مطور';
      case Role.provider:
        return 'مزود خدمة';
      case Role.seller:
        return 'بائع';
      case Role.driver:
        return 'سائق';
      case Role.delivery:
        return 'دليفري';
    }
  }

  /// Role description explaining what this role does
  String get description {
    switch (this) {
      case Role.client:
        return 'اطلب الخدمات المنزلية، تسوق المنتجات، واستخدم خدمات التوصيل والمشاوير';
      case Role.admin:
        return 'إدارة التطبيق كاملاً: المستخدمين، الطلبات، التقارير، والإعدادات';
      case Role.developer:
        return 'إعدادات المطورين والتجارب التقنية';
      case Role.provider:
        return 'قدم الخدمات المنزلية مثل التنظيف، الصيانة، والنجارة';
      case Role.seller:
        return 'بيع المنتجات عبر المتجر الإلكتروني المتكامل';
      case Role.driver:
        return 'خدمات النقل والرحلات للمستخدمين';
      case Role.delivery:
        return 'توصيل الطلبات والمنتجات للمستخدمين';
    }
  }

  /// Icon data for UI
  IconData get icon {
    switch (this) {
      case Role.client:
        return Icons.person_outline_rounded;
      case Role.admin:
        return Icons.admin_panel_settings_rounded;
      case Role.developer:
        return Icons.code_rounded;
      case Role.provider:
        return Icons.home_repair_service_rounded;
      case Role.seller:
        return Icons.shopping_bag_outlined;
      case Role.driver:
        return Icons.drive_eta_rounded;
      case Role.delivery:
        return Icons.local_shipping_rounded;
    }
  }

  /// Registration icon (filled version)
  IconData get filledIcon {
    switch (this) {
      case Role.client:
        return Icons.person_rounded;
      case Role.admin:
        return Icons.admin_panel_settings_rounded;
      case Role.developer:
        return Icons.code_rounded;
      case Role.provider:
        return Icons.home_repair_service_rounded;
      case Role.seller:
        return Icons.shopping_bag_rounded;
      case Role.driver:
        return Icons.drive_eta_rounded;
      case Role.delivery:
        return Icons.local_shipping_rounded;
    }
  }

  /// Role group for UI grouping and navigation
  RoleGroup get group {
    switch (this) {
      case Role.client:
        return RoleGroup.consumer;
      case Role.admin:
      case Role.developer:
        return RoleGroup.platform;
      case Role.provider:
      case Role.seller:
      case Role.driver:
      case Role.delivery:
        return RoleGroup.partner;
    }
  }

  /// Determines if this role requires partner/merchant registration
  bool get requiresPartnerRegistration {
    return this == Role.provider ||
           this == Role.seller ||
           this == Role.driver ||
           this == Role.delivery;
  }

  /// Determines if this role has a dedicated wallet/earnings system
  bool get hasWallet {
    return this == Role.provider ||
           this == Role.seller ||
           this == Role.driver ||
           this == Role.delivery;
  }

  /// Determines if this role provides services/products directly
  bool get isProviderRole {
    return this == Role.provider ||
           this == Role.seller ||
           this == Role.driver ||
           this == Role.delivery;
  }

  /// Determines if this role consumes services
  bool get isClientRole => this == Role.client;

  /// Determines if this role has admin privileges
  bool get isAdminRole => this == Role.admin;

  /// Determines if this role has developer access
  bool get isDeveloperRole => this == Role.developer;

  /// Converts from string value (from database or API)
  static Role fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'client':
      case 'عميل':
        return Role.client;
      case 'admin':
      case 'ادمن':
        return Role.admin;
      case 'developer':
      case 'مطور':
        return Role.developer;
      case 'provider':
      case 'مزود خدمة':
      case 'مزود_خدمة':
        return Role.provider;
      case 'seller':
      case 'بائع':
        return Role.seller;
      case 'driver':
      case 'سائق':
        return Role.driver;
      case 'delivery':
      case 'سائق دليفري':
      case 'سائق_دليفري':
        return Role.delivery;
      default:
        return Role.client; // default fallback
    }
  }

  /// Converts to string for database storage
  String get asString {
    switch (this) {
      case Role.client:
        return 'client';
      case Role.admin:
        return 'admin';
      case Role.developer:
        return 'developer';
      case Role.provider:
        return 'provider';
      case Role.seller:
        return 'seller';
      case Role.driver:
        return 'driver';
      case Role.delivery:
        return 'delivery';
    }
  }
}

/// Groups roles by category for UI organization
enum RoleGroup {
  consumer,       // End users who consume services
  platform,       // Platform management roles
  partner,        // Partners who provide services/sells/drive
}

extension RoleGroupExtension on RoleGroup {
  String get nameAr {
    switch (this) {
      case RoleGroup.consumer:
        return 'عملاء';
      case RoleGroup.platform:
        return 'منصة';
      case RoleGroup.partner:
        return 'شركاء';
    }
  }
}

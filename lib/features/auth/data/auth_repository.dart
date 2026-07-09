// ═══════════════════════════════════════════════════════════════════════════════
// Auth Repository
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faster_app/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:faster_app/core/stubs/stub_auth_repository.dart';

class AuthRepository {
  final _auth = SupabaseService.auth;
  final _db = SupabaseService.db;

  MockAuthRepository? get _bypassAuth =>
      SupabaseService.isBypassMode ? MockAuthRepository() : null;

  // Sign Up
  Future<Map<String, dynamic>> signUp({
    required String phone,
    required String password,
    String? email,
    required String fullName,
    required String role, // 'client', 'admin', 'developer', 'provider', 'seller', 'driver', 'delivery'
    // Provider-specific fields
    String? profession,
    int? categoryId,
    String? nationalIdNumber,
    String? bio,
    String? referredBy,
    String? providerType,
    // Additional partner fields
    String? storeAddress,
    String? taxId,
    String? vehicleModel,
    String? vehiclePlate,
    String? deliveryArea,
  }) async {
    if (SupabaseService.isBypassMode) {
return _bypassAuth!.signUp(
    phone: phone,
    password: password,
    email: email,
    fullName: fullName,
    role: role,
  );
    }

    try {
      debugPrint('=== SIGN UP START ===');
      debugPrint('Phone: $phone');
      debugPrint('Email: $email');
      debugPrint('Name: $fullName');
      debugPrint('Role: $role');
      debugPrint('Password length: ${password.length}');

      // Determine if using email or phone for auth
      String authEmail;
      String formattedPhone = phone;

      // Always use email for authentication (both phone and email are required)
      authEmail = email!;
      debugPrint('Using email for authentication: $authEmail');

      // Format phone number for storage
      formattedPhone = _formatPhoneNumber(phone);
      debugPrint('Formatted phone for storage: $formattedPhone');

      // 1. إنشاء الحساب في نظام الـ Auth الخاص بـ Supabase
      debugPrint('Calling Supabase signUp...');
      final response = await _auth.signUp(
        email: authEmail,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

      debugPrint('Sign up response received');
      final user = response.user;
      if (user == null) {
        debugPrint('Sign up failed: user is null');
        return {
          'success': false,
          'error': 'فشل إنشاء الحساب، يرجى المحاولة لاحقاً',
        };
      }

      debugPrint('User created successfully: ${user.id}');

      // 2. حفظ البيانات الأساسية في جدول profiles
      debugPrint('Saving profile to database...');
      try {
        final profileData = {
          'id': user.id,
          'full_name': fullName,
          'role': role,
          'is_verified': role == 'client',
          'phone_number': formattedPhone,
          'email': email,
          if (referredBy != null) 'referred_by': referredBy,
        };

        // Add optional fields if provided
        if (profession != null) profileData['profession'] = profession;
        if (categoryId != null) profileData['category_id'] = categoryId;
        if (nationalIdNumber != null) profileData['national_id_number'] = nationalIdNumber;
        if (bio != null) profileData['bio'] = bio;
        if (providerType != null) profileData['provider_type'] = providerType;
        if (storeAddress != null) profileData['store_address'] = storeAddress;
        if (taxId != null) profileData['tax_id'] = taxId;
        if (vehicleModel != null) profileData['vehicle_model'] = vehicleModel;
        if (vehiclePlate != null) profileData['vehicle_plate'] = vehiclePlate;
        if (deliveryArea != null) profileData['delivery_area'] = deliveryArea;

        await _db.from('profiles').insert(profileData);
        debugPrint('Profile saved successfully');
      } catch (e) {
        debugPrint('Error saving profile: $e');
        // If profile insertion fails, we should clean up the auth user
        // but for now we'll just return the error
        return {
          'success': false,
          'error': 'فشل حفظ البيانات: ${e.toString()}',
        };
      }

      // 3. Create auth session
      debugPrint('Creating session...');
      try {
        await _auth.signIn(
          email: authEmail,
          password: password,
        );
        debugPrint('Session created successfully');
      } catch (e) {
        debugPrint('Session creation error: $e');
      }

      // 4. إذا كان المستخدم عميلاً، نقوم بتسجيل الدخول مباشرة
      if (role == 'client') {
        debugPrint('Client role - auto login successful');
        return {
          'success': true,
          'role': role,
          'message': 'تم إنشاء الحساب بنجاح',
        };
      }

      // For provider/seller/driver/delivery - account requires verification
      debugPrint('Partner role - needs verification');
      return {
        'success': true,
        'role': role,
        'message': 'تم إنشاء الحساب بنجاح، يرجى انتظار التحقق من الإدارة',
        'needs_verification': true,
      };
    } catch (e) {
      debugPrint('Sign up error: $e');
      return {
        'success': false,
        'error': 'فشل إنشاء الحساب: ${e.toString()}',
      };
    }
  }

  // Sign In
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseService.isBypassMode) {
      return _bypassAuth!.login(phone: email, password: password);
    }

    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return {'success': false, 'error': 'بيانات الدخول غير صحيحة'};
      }

      final role = user.userMetadata?['role'] as String? ?? 'client';
      return {
        'success': true,
        'role': role,
        'user_id': user.id,
        'message': 'تم تسجيل الدخول بنجاح',
      };
    } catch (e) {
      return {'success': false, 'error': 'خطأ في تسجيل الدخول: ${e.toString()}'};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    if (SupabaseService.isBypassMode) {
      await _bypassAuth!.logout();
      return;
    }
    await _auth.signOut();
  }

  // Get Current Role
  Future<String?> getCurrentRole() async {
    if (SupabaseService.isBypassMode) {
      return _bypassAuth!.getCurrentRole();
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final role = user.userMetadata?['role'] as String?;
      return role;
    } catch (e) {
      return null;
    }
  }

  // Get Current User ID
  String? get currentUserId {
    if (SupabaseService.isBypassMode) return 'usr_${DateTime.now().millisecondsSinceEpoch}';
    return _auth.currentUser?.id;
  }

  // Refresh session
  Future<bool> refreshSession() async {
    if (SupabaseService.isBypassMode) return true;
    try {
      final response = await _auth.refreshSession();
      return response.user != null;
    } catch (e) {
      return false;
    }
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    if (SupabaseService.isBypassMode) return;
    await _auth.resetPassword(email: email);
  }

  String _formatPhoneNumber(String phone) {
    // Remove any spaces, dashes, or parentheses
    String formatted = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Handle Saudi numbers
    if (formatted.startsWith('0')) {
      formatted = '+966${formatted.substring(1)}';
    } else if (formatted.startsWith('5')) {
      formatted = '+966$formatted';
    } else if (!formatted.startsWith('+')) {
      formatted = '+966$formatted';
    }

    return formatted;
  }
}

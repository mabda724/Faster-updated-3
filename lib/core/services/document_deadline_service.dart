import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Service to check if a provider has completed document upload
/// within the 15-day grace period.
class DocumentDeadlineService {
  static const int gracePeriodDays = 15;

  /// Check if the current provider needs to upload documents
  /// Returns a map with status info:
  /// - needsUpload: bool
  /// - daysRemaining: int
  /// - isExpired: bool (grace period exceeded)
  /// - isDocumentComplete: bool
  static Future<Map<String, dynamic>> checkDeadline() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return {'needsUpload': false, 'daysRemaining': 0, 'isExpired': false, 'isDocumentComplete': true};

      // Get provider profile with registration date and verification status
      final profile = await SupabaseService.db
          .from('provider_profiles')
          .select('document_verification_status, created_at')
          .eq('id', uid)
          .maybeSingle();

      if (profile == null) return {'needsUpload': false, 'daysRemaining': 0, 'isExpired': false, 'isDocumentComplete': true};

      final isComplete = profile['document_verification_status'] == 'approved';
      final registrationDateStr = profile['created_at'];
      
      if (isComplete) {
        return {'needsUpload': false, 'daysRemaining': 0, 'isExpired': false, 'isDocumentComplete': true};
      }

      // Calculate days since registration
      final registrationDate = DateTime.tryParse(registrationDateStr?.toString() ?? '');
      if (registrationDate == null) {
        return {'needsUpload': true, 'daysRemaining': gracePeriodDays, 'isExpired': false, 'isDocumentComplete': false};
      }

      final daysSinceRegistration = DateTime.now().difference(registrationDate).inDays;
      final daysRemaining = (gracePeriodDays - daysSinceRegistration).clamp(0, gracePeriodDays);
      final isExpired = daysSinceRegistration >= gracePeriodDays;

      // Auto-ban if expired and documents not complete
      if (isExpired && !isComplete) {
        await _autoBanProvider(uid);
      }

      return {
        'needsUpload': !isComplete,
        'daysRemaining': daysRemaining,
        'isExpired': isExpired,
        'isDocumentComplete': isComplete,
      };
    } catch (e) {
      debugPrint('Error checking document deadline: $e');
      return {'needsUpload': false, 'daysRemaining': 0, 'isExpired': false, 'isDocumentComplete': true};
    }
  }

  /// Auto-ban provider who didn't upload documents in time
  static Future<void> _autoBanProvider(String providerId) async {
    try {
      await SupabaseService.db.from('profiles').update({
        'banned_at': DateTime.now().toIso8601String(),
        'ban_reason': 'لم يتم رفع الوثائق المطلوبة خلال المهلة المحددة ($gracePeriodDays يوم)',
      }).eq('id', providerId);

      // Create warning record
      await SupabaseService.db.from('admin_warnings').insert({
        'provider_id': providerId,
        'warning_type': 'auto_ban_missing_docs',
        'message': 'تم حظر الحساب تلقائياً بسبب عدم رفع الوثائق خلال $gracePeriodDays يوم',
        'action_taken': 'banned',
      });
    } catch (e) {
      debugPrint('Error auto-banning provider: $e');
    }
  }
}

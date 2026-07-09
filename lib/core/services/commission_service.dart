import '../../core/services/supabase_service.dart';
import '../../core/constants/app_constants.dart';

class CommissionService {
  final _db = SupabaseService.db;

  double _normalizeRate(double rate) {
    if (rate > 1) return rate / 100;
    if (rate < 0) return 0;
    return rate;
  }

  /// Get commission rate from app_settings
  Future<double> getCommissionRate() async {
    try {
      final settings = await _db
          .from('app_settings')
          .select()
          .inFilter('key', ['commission_rate', 'default_commission_rate'])
          .maybeSingle();

      if (settings != null) {
        final parsed = double.tryParse(settings['value'].toString()) ??
            AppConstants.defaultCommissionRate;
        return _normalizeRate(parsed);
      }
      return _normalizeRate(AppConstants.defaultCommissionRate);
    } catch (e) {
      return _normalizeRate(AppConstants.defaultCommissionRate);
    }
  }

  /// Calculate commission amount
  double calculateCommission(double servicePrice, double commissionRate) {
    return servicePrice * _normalizeRate(commissionRate);
  }

  /// Calculate provider earning
  double calculateProviderEarning(double servicePrice, double commissionRate) {
    return servicePrice - calculateCommission(servicePrice, commissionRate);
  }
}

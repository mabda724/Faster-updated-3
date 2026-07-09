import '../services/supabase_service.dart';

class ProviderSearchService {
  static const List<int> defaultTiers = [3, 5, 10, 20];

  /// Find providers using graduated radius search.
  /// Tries each radius in [tiers] until providers are found.
  /// Returns {providers, radiusUsed} or empty list with -1 radius.
  static Future<Map<String, dynamic>> findNearby({
    required double lat,
    required double lng,
    List<int>? tiers,
    int? serviceCategoryId,
  }) async {
    final radii = tiers ?? defaultTiers;
    for (final km in radii) {
      try {
        final res = await SupabaseService.db.rpc(
          'find_providers_within_radius',
          params: {
            'client_lat': lat,
            'client_lng': lng,
            'radius_km': km.toDouble(),
            if (serviceCategoryId != null) 'service_category_id': serviceCategoryId,
          },
        );
        final list = (res as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          return {'providers': list, 'radiusUsed': km};
        }
      } catch (_) {}
    }
    return {'providers': <Map<String, dynamic>>[], 'radiusUsed': -1};
  }

  /// Find providers filtered by rating tier.
  /// Tier options: 'gold' (4.5+), 'silver' (4.0+), 'bronze' (3.5+), 'new' (<3.5)
  static Future<List<Map<String, dynamic>>> findByRatingTier({
    required String ratingTier,
    required double lat,
    required double lng,
    double radiusKm = 20,
  }) async {
    try {
      final res = await SupabaseService.db
          .from('provider_profiles')
          .select('*, profiles(full_name, avatar_url, phone)')
          .eq('rating_tier', ratingTier)
          .eq('is_online', true)
          .eq('is_verified', true)
          .gte('current_lat', lat - (radiusKm / 111))
          .lte('current_lat', lat + (radiusKm / 111))
          .gte('current_lng', lng - (radiusKm / 111))
          .lte('current_lng', lng + (radiusKm / 111))
          .order('avg_rating', ascending: false);
      
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Get all providers sorted by rating (highest first)
  static Future<List<Map<String, dynamic>>> getTopRatedProviders({
    required double lat,
    required double lng,
    double radiusKm = 20,
    int limit = 20,
  }) async {
    try {
      final res = await SupabaseService.db
          .from('provider_profiles')
          .select('*, profiles(full_name, avatar_url, phone)')
          .eq('is_online', true)
          .eq('is_verified', true)
          .gte('current_lat', lat - (radiusKm / 111))
          .lte('current_lat', lat + (radiusKm / 111))
          .gte('current_lng', lng - (radiusKm / 111))
          .lte('current_lng', lng + (radiusKm / 111))
          .order('avg_rating', ascending: false)
          .limit(limit);
      
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}

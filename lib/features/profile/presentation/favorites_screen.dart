import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _favoriteServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // Load favorite service IDs
      final favs = await SupabaseService.db
          .from('favorite_services')
          .select('service_id')
          .eq('client_id', uid);
      final favIds =
          (favs as List).map<int>((e) => e['service_id'] as int).toList();
      if (favIds.isEmpty) {
        setState(() {
          _favoriteServices = [];
          _isLoading = false;
        });
        return;
      }
      // Load service details for favorite IDs
      final services = await SupabaseService.db
          .from('services')
          .select(''',
            *,
            categories(name_ar, name_en)
          ''')
          .filter('id', 'in', '(${favIds.map((id) => '"$id"').join(',')})')
          .order('created_at', ascending: false);
      setState(() {
        _favoriteServices = List<Map<String, dynamic>>.from(services);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(int serviceId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.db
          .from('favorite_services')
          .delete()
          .eq('client_id', uid)
          .eq('service_id', serviceId);
      setState(() {
        _favoriteServices.removeWhere((s) => s['id'] == serviceId);
      });
    } catch (_) {}
  }

  String _getServiceImage(Map<String, dynamic> service) {
    final imageUrl = service['image_url'];
    if (imageUrl != null && imageUrl.toString().startsWith('http')) {
      return imageUrl.toString();
    }
    return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400&q=80';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteServices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.favorite_border_rounded,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('قائمة المفضلة فارغة',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('أضف الخدمات التي تعجبك للوصول إليها لاحقاً',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  itemCount: _favoriteServices.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final service = _favoriteServices[index];
                    final cat = service['categories'] ?? {};
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _getServiceImage(service),
                            width: 56.w,
                            height: 56.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(service['title'] ?? ''),
                        subtitle: Text(cat['name_ar'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite_rounded,
                              color: AppTheme.errorColor),
                          onPressed: () =>
                              _removeFavorite(service['id'] as int),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

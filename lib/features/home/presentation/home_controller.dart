import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/auth_repository.dart';

class HomeController extends ChangeNotifier {
  String userName = '';
  String currentAddress = 'Hurgada'; // Default
  int activeOrdersCount = 0;
  bool isLoading = true;

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();
    try {
      final profile = await AuthRepository().getCurrentProfile();
      userName = profile?['full_name'] ?? 'User';
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        final orders = await SupabaseService.db
            .from('bookings')
            .select('id')
            .eq('client_id', uid)
            .inFilter('status', ['pending', 'accepted', 'on_the_way', 'arrived', 'in_progress']);
        activeOrdersCount = (orders as List).length;
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
    }
    isLoading = false;
    notifyListeners();
  }
}

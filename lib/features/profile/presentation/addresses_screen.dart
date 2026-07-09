import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faster_app/core/services/supabase_service.dart';
import 'package:faster_app/core/utils/snackbar_utils.dart';
import '../../../core/widgets/map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final data = await SupabaseService.db.from('addresses').select().order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _addresses = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(String id) async {
    try {
      await SupabaseService.db.from('addresses').delete().eq('id', id);
      _loadAddresses();
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'فشل الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عناويني')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1), child: const Icon(Icons.location_on, color: AppTheme.primaryColor)),
                        title: Text(addr['title'] ?? ''),
                        subtitle: Text(addr['full_address'] ?? ''),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'حذف', onPressed: () => _deleteAddress(addr['id'])),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAddressDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('لا توجد عناوين مسجلة', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }


  void _showAddAddressDialog() {
    final titleController = TextEditingController();
    final addressController = TextEditingController();
    LatLng? selectedLatLng;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إضافة عنوان جديد', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController, 
                decoration: const InputDecoration(labelText: 'الاسم (منزل، عمل...)', border: OutlineInputBorder())
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                  );
                  if (result != null) {
                    setDialogState(() {
                      selectedLatLng = result['location'];
                      addressController.text = result['address'];
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          addressController.text.isEmpty ? 'حدد الموقع على الخريطة' : addressController.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: addressController.text.isEmpty ? Colors.grey : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (titleController.text.isNotEmpty && addressController.text.isNotEmpty) {
                  try {
                    await SupabaseService.db.from('addresses').insert({
                      'user_id': SupabaseService.client.auth.currentUser!.id,
                      'title': titleController.text,
                      'full_address': addressController.text,
                      'lat': selectedLatLng?.latitude,
                      'lng': selectedLatLng?.longitude,
                    });
                    if (context.mounted) Navigator.pop(context);
                    _loadAddresses();
                  } catch (e) {
                    debugPrint('Error: $e');
                  }
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

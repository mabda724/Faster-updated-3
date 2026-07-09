import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;

  // Use central config
  final String _backendUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  void _showMessage(String msg, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            isDefaultAction: true,
            isDestructiveAction: isError,
            child: const Text('حسنا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.db
          .from('profiles')
          .select('*, provider_profiles(*)')
          .eq('role', 'provider')
          .order('created_at', ascending: false);

      setState(() {
        _providers = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) _showMessage('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleVerification(String id, bool currentStatus) async {
    setState(() => _isLoading = true);
    try {
      // We call the BACKEND instead of Supabase directly to bypass client-side RLS
      final res = await http.post(
        Uri.parse('$_backendUrl/api/admin/toggle-provider'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'verify': !currentStatus,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) _showMessage('تم تحديث الحالة بنجاح');
        _loadProviders();
      } else {
        throw Exception('Server Error: ${res.body}');
      }
    } catch (e) {
      if (mounted) _showMessage('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? const Center(child: Text('لا يوجد مقدمي خدمة حالياً'))
              : SafeArea(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _providers.length,
                    itemBuilder: (context, index) {
                      final p = _providers[index];
                      final isVerified = p['is_verified'] == true;

                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DesignTokens.brMd,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(DesignTokens.space4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['full_name'] ?? 'بدون اسم',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${p['id'].toString().substring(0, 8)}...\nالحالة: ${isVerified ? 'نشط' : 'بانتظار التنشيط'}',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isVerified,
                                activeTrackColor: AppTheme.successColor,
                                onChanged: (_) => _toggleVerification(p['id'], isVerified),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

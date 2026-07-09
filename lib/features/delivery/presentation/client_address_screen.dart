import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ClientAddressScreen extends StatefulWidget {
  final void Function(String address, String label)? onSelected;
  const ClientAddressScreen({super.key, this.onSelected});

  @override
  State<ClientAddressScreen> createState() => _ClientAddressScreenState();
}

class _ClientAddressScreenState extends State<ClientAddressScreen> {
  int _selected = 0;
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  static const Color _purple = AppTheme.primaryColor;
  static const Color _lightPurple = AppTheme.backgroundColor;
  static const Color _bgGray = AppTheme.surfaceColor70;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final res = await SupabaseService.db
          .from('customer_addresses')
          .select()
          .eq('user_id', uid)
          .order('is_default', ascending: false);
      if (mounted) {
        _addresses = List<Map<String, dynamic>>.from(res);
        _selected = _addresses.indexWhere((a) => a['is_default'] == true);
        if (_selected < 0 && _addresses.isNotEmpty) _selected = 0;
      }
    } catch (e) {
      debugPrint('Load addresses error: ');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addAddress() async {
    final labelCtrl = TextEditingController();
    final addrCtrl = TextEditingController(text: 'شارع السياحة - الغردقة');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('عنوان جديد', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl, textDirection: TextDirection.rtl,
              decoration: InputDecoration(hintText: 'تسمية (المنزل، العمل...)', filled: true, fillColor: _bgGray,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
          SizedBox(height: 8.h),
          TextField(controller: addrCtrl, textDirection: TextDirection.rtl,
              decoration: InputDecoration(hintText: 'العنوان', filled: true, fillColor: _bgGray,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (labelCtrl.text.trim().isEmpty) return;
              try {
                await SupabaseService.db.from('customer_addresses').insert({
                  'user_id': SupabaseService.currentUserId,
                  'label': labelCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'is_default': _addresses.isEmpty,
                });
                if (ctx.mounted) Navigator.pop(ctx, {'label': labelCtrl.text.trim(), 'address': addrCtrl.text.trim()});
              } catch (e) {
                debugPrint('Add address error: ');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkBackgroundColor),
            onPressed: () => Navigator.pop(context)),
        title: Text('عنوان التوصيل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppTheme.darkBackgroundColor)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(padding: EdgeInsets.all(16.w), children: [
                    InkWell(
                      onTap: _addAddress,
                      child: Container(
                        width: double.infinity, padding: EdgeInsets.symmetric(vertical: 14.h),
                        decoration: BoxDecoration(
                          border: Border.all(color: _purple.withValues(alpha: 0.25), width: 2, style: BorderStyle.solid),
                          color: _lightPurple.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_circle_rounded, color: _purple, size: 16),
                          SizedBox(width: 8.w),
                          Text('إضافة عنوان جديد',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: _purple)),
                        ]),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (_addresses.isEmpty)
                      Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.h),
                        child: Text('لا توجد عناوين. أضف عنواناً جديداً',
                            style: TextStyle(color: Colors.grey[400])),
                      )),
                    ...List.generate(_addresses.length, (i) {
                      final a = _addresses[i];
                      final active = _selected == i;
                      final label = a['label'] as String? ?? '';
                      final address = a['address'] as String? ?? '';
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: active ? _lightPurple.withValues(alpha: 0.4) : Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: active ? _purple : Colors.grey[100]!, width: active ? 2 : 1),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _selected = i),
                            borderRadius: BorderRadius.circular(16.r),
                            child: Row(children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: active ? _purple.withValues(alpha: 0.2) : Colors.grey[200]!)),
                                child: Icon(_icon(label), size: 14, color: active ? _purple : Colors.grey[400]),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: AppTheme.darkBackgroundColor)),
                                SizedBox(height: 4.h),
                                Text(address, style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
                              ])),
                              Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: active ? _purple : Colors.grey[300]!, width: active ? 4 : 1.5),
                                  color: active ? Colors.white : Colors.transparent,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ]),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).padding.bottom + 16.h),
                  decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[50]!))),
                  child: SizedBox(
                    width: double.infinity, height: 48.h,
                    child: ElevatedButton(
                      onPressed: _addresses.isEmpty ? null : () {
                        final a = _addresses[_selected];
                        widget.onSelected?.call(a['address'] as String? ?? '', a['label'] as String? ?? '');
                        if (widget.onSelected == null) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 4, shadowColor: _purple.withValues(alpha: 0.3),
                      ),
                      child: Text('متابعة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  IconData _icon(String label) {
    switch (label) {
      case 'المنزل': return Icons.home_rounded;
      case 'العمل': return Icons.business_center_rounded;
      case 'الفيلا': return Icons.business_rounded;
      default: return Icons.location_on_rounded;
    }
  }
}

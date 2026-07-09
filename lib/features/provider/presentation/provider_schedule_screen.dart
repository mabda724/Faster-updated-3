import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class ProviderScheduleScreen extends StatefulWidget {
  const ProviderScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ProviderScheduleScreen> createState() => _ProviderScheduleScreenState();
}

class _ProviderScheduleScreenState extends State<ProviderScheduleScreen> {
  // Map dayOfWeek (1-7) -> list of slots {id?, start, end}
  Map<int, List<Map<String, dynamic>>> _schedule = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final res = await SupabaseService.db
          .from('provider_schedules')
          .select('id, day_of_week, start_time, end_time')
          .eq('provider_id', uid);
      final List rows = res as List;
      final Map<int, List<Map<String, dynamic>>> map = {};
      for (var r in rows) {
        final int day = r['day_of_week'] as int;
        map.putIfAbsent(day, () => []).add(r as Map<String, dynamic>);
      }
      setState(() {
        _schedule = map;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading schedule: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddOrEditDialog({int? slotId, required int dayOfWeek, String? start, String? end}) async {
    final startCtrl = TextEditingController(text: start ?? '');
    final endCtrl = TextEditingController(text: end ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(slotId == null ? 'إضافة فترة' : 'تعديل فترة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startCtrl,
                decoration: InputDecoration(
                  hintText: 'وقت البداية (HH:MM)',
                  contentPadding: EdgeInsets.all(DesignTokens.space6),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.space6),
              TextField(
                controller: endCtrl,
                decoration: InputDecoration(
                  hintText: 'وقت النهاية (HH:MM)',
                  contentPadding: EdgeInsets.all(DesignTokens.space6),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(ctx),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                final startTime = startCtrl.text.trim();
                final endTime = endCtrl.text.trim();
                if (startTime.isEmpty || endTime.isEmpty) {
                  _showSnack('الرجاء إدخال الوقت');
                  setStateDialog(() => isSaving = false);
                  return;
                }
                try {
                  await SupabaseService.upsertProviderSchedule(
                    id: slotId,
                    dayOfWeek: dayOfWeek,
                    startTime: startTime,
                    endTime: endTime,
                  );
                  await _loadSchedule();
                  Navigator.pop(ctx);
                } catch (e) {
                  _showSnack('خطأ: $e');
                } finally {
                  setStateDialog(() => isSaving = false);
                }
              },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSlot(int slotId) async {
    try {
      await SupabaseService.db.from('provider_schedules').delete().eq('id', slotId);
      await _loadSchedule();
    } catch (e) {
      _showSnack('خطأ حذف: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildDayColumn(int day) {
    final slots = _schedule[day] ?? [];
    final dayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayNames[day - 1],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontSize: DesignTokens.textLabelLarge,
            ),
          ),
          SizedBox(height: DesignTokens.space4),
          ...slots.map((s) => Container(
                margin: EdgeInsets.symmetric(vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.textPrimary.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(DesignTokens.space4),
                        child: Text(
                          '${s['start_time']} - ${s['end_time']}',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: DesignTokens.textBodySmall,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.all(DesignTokens.space2),
                        foregroundColor: AppTheme.primaryColor,
                      ),
                      onPressed: () => _showAddOrEditDialog(
                        slotId: s['id'],
                        dayOfWeek: day,
                        start: s['start_time'],
                        end: s['end_time'],
                      ),
                      child: Icon(Icons.edit_rounded, size: 16, color: AppTheme.primaryColor),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.all(DesignTokens.space2),
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () => _deleteSlot(s['id'] as int),
                      child: Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                    ),
                  ],
                ),
              )),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppTheme.primaryColor,
            ),
            onPressed: () => _showAddOrEditDialog(dayOfWeek: day),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 16),
                SizedBox(width: DesignTokens.space2),
                Text(
                  'إضافة فترة',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: DesignTokens.textLabelMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.all(DesignTokens.space8),
                child: Row(
                  children: [
                    for (int d = 1; d <= 7; d++) _buildDayColumn(d),
                  ],
                ),
              ),
      ),
    );
  }
}

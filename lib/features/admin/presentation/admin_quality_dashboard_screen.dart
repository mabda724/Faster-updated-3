import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class AdminQualityDashboardScreen extends StatefulWidget {
  const AdminQualityDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminQualityDashboardScreen> createState() => _AdminQualityDashboardScreenState();
}

class _AdminQualityDashboardScreenState extends State<AdminQualityDashboardScreen> {
  Map<String, dynamic>? _metrics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final data = await SupabaseService.db.from('admin_quality_metrics').select().maybeSingle();
      setState(() {
        _metrics = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading quality metrics: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _exportCSV() async {
    try {
      final url = Uri.parse('https://your-supabase-url.functions.v1/export_quality_csv');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Save file locally (simplified: just show SnackBar)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CSV exported successfully'),
          backgroundColor: Colors.green,
        ));
        // In a real app, you would write the CSV to device storage or download.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export CSV: ${response.body}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error exporting CSV: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            Icon(icon, size: DesignTokens.iconLg, color: color),
            const SizedBox(width: DesignTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جودة الخدمة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(DesignTokens.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text('مقاييس الجودة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: DesignTokens.space8),
                  Text('نظرة عامة على أداء الخدمة', style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: DesignTokens.space24),
                  // Metrics grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: DesignTokens.space16,
                      mainAxisSpacing: DesignTokens.space16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildMetricCard(
                          'إجمالي الطلبات',
                          '${_metrics?['total_bookings'] ?? 0}',
                          Icons.receipt_long_rounded,
                          AppTheme.primaryColor,
                        ),
                        _buildMetricCard(
                          'معدل القبول',
                          '${(_metrics?['acceptance_rate'] ?? 0).toStringAsFixed(1)}%',
                          Icons.check_circle_outline_rounded,
                          _metrics?['acceptance_rate'] != null && _metrics!['acceptance_rate'] > 0.7
                              ? AppTheme.successColor
                              : AppTheme.tertiaryColor,
                        ),
                        _buildMetricCard(
                          'متوسط التقييم المزود',
                          '${(_metrics?['avg_provider_rating'] ?? 0).toStringAsFixed(1)}',
                          Icons.star_outline_rounded,
                          AppTheme.tertiaryColor,
                        ),
                        _buildMetricCard(
                          'إجمالي الشكاوى',
                          '${_metrics?['total_complaints'] ?? 0}',
                          Icons.warning_amber_rounded,
                          AppTheme.errorColor,
                        ),
                        _buildMetricCard(
                          'متوسط وقت الاستجابة',
                          '${(_metrics?['avg_response_time_minutes'] ?? 0).toStringAsFixed(0)} دقيقة',
                          Icons.timer_rounded,
                          AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space20),
                  // Export button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _exportCSV,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('تصدير CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: DesignTokens.space12),
                        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

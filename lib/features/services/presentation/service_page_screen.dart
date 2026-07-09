import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../booking/presentation/client_checkout_screen.dart';
import '../../provider/presentation/provider_details_screen.dart';
import 'package:latlong2/latlong.dart';

class ServicePageScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String? categoryId;
  final int providerCount;
  final List<String> subServices;
  final double? basePrice;

  const ServicePageScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    this.categoryId,
    required this.providerCount,
    required this.subServices,
    this.basePrice,
  });

  @override
  State<ServicePageScreen> createState() => _ServicePageScreenState();
}

class _ServicePageScreenState extends State<ServicePageScreen> {
  Map<String, dynamic>? _serviceData;
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServiceData();
  }

  Future<void> _loadServiceData() async {
    try {
      if (widget.serviceId != '0') {
        final service = await SupabaseService.db
            .from('services')
            .select('*, categories(name_ar)')
            .eq('id', widget.serviceId)
            .maybeSingle();

        if (service != null) {
          setState(() => _serviceData = service);
        }

        final providersData = await SupabaseService.db
            .from('provider_services')
            .select('''
              provider_id,
              price,
              provider_profiles(
                id,
                profession,
                rating,
                is_online,
                profiles(full_name, avatar_url, is_verified)
              )
            ''')
            .eq('service_id', widget.serviceId);

        final enrichedProviders = <Map<String, dynamic>>[];
        for (final p in providersData) {
          final pp = p['provider_profiles'] as Map<String, dynamic>?;
          if (pp != null) {
            enrichedProviders.add({
              'id': pp['id'],
              'name': pp['profiles']?['full_name'] ?? 'مقدم خدمة',
              'avatar': pp['profiles']?['avatar_url'],
              'profession': pp['profession'] ?? widget.serviceName,
              'rating': pp['rating'] ?? 0.0,
              'isOnline': pp['is_online'] ?? false,
              'isVerified': pp['profiles']?['is_verified'] ?? false,
              'price': p['price'] ?? widget.basePrice ?? 0,
            });
          }
        }
        setState(() => _providers = enrichedProviders);
      }
    } catch (e) {
      debugPrint('Error loading service: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Semantics(label: 'العودة',
            child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
            ),
          ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.serviceName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  '${widget.providerCount} مقدم خدمة متاح',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceDetails(),
          SizedBox(height: 24.h),
          _buildBookingOptions(),
          SizedBox(height: 24.h),
          _buildProvidersList(),
        ],
      ),
    );
  }

  Widget _buildServiceDetails() {
    final price = _serviceData?['price'] ?? widget.basePrice ?? 0;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.build_rounded, color: AppTheme.primaryColor, size: 32),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.serviceName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    if (_serviceData?['description'] != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        _serviceData!['description'],
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (price > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('السعر يبدأ من', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                Text(
                  '${price.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          if (widget.subServices.isNotEmpty) ...[
            const Text('الخدمات الفرعية:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: widget.subServices.map((sub) => Chip(
                label: Text(sub, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.backgroundColor,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر طريقة الحجز',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: _buildBookingOption(
              icon: Icons.flash_on_rounded,
              title: 'أحجز الآن',
              subtitle: 'تواصل مع أقرب مقدم',
              color: AppTheme.successColor,
              onTap: () => _showProviderSelection(false),
            )),
            SizedBox(width: 12.w),
            Expanded(child: _buildBookingOption(
              icon: Icons.calendar_today_rounded,
              title: 'حدد موعد',
              subtitle: 'اختر التاريخ والوقت',
              color: AppTheme.infoColor,
              onTap: () => _showProviderSelection(true),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildBookingOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: title,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 12.h),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 4.h),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersList() {
    if (_providers.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.engineering_outlined, size: 64, color: AppTheme.textTertiary),
            SizedBox(height: 16.h),
            const Text('لا يوجد مقدمي خدمة حالياً', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مقدمو الخدمة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        SizedBox(height: 12.h),
        ...List.generate(_providers.length, (index) => _buildProviderCard(index)),
      ],
    );
  }

  Widget _buildProviderCard(int index) {
    final p = _providers[index];
    final isOnline = p['isOnline'] ?? false;

    return Semantics(
      label: 'تفاصيل مقدم الخدمة',
      child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDetailsScreen(providerId: p['id'].toString()),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28.r,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: p['avatar'] != null ? NetworkImage(p['avatar']) : null,
                  child: p['avatar'] == null ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor) : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle, border: Border.all(color: AppTheme.surfaceColor, width: 2)),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(p['name'] ?? 'مقدم خدمة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (p['isVerified'] == true) ...[
                        SizedBox(width: DesignTokens.space2),
                        Icon(Icons.verified_rounded, size: 14, color: AppTheme.primaryColor),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: AppTheme.tertiaryColor),
                      SizedBox(width: 4.w),
                      Text('${p['rating']}', style: const TextStyle(fontSize: 12)),
                      SizedBox(width: 12.w),
                      Text(
                        isOnline ? 'متصل الآن' : 'غير متصل',
                        style: TextStyle(fontSize: 11, color: isOnline ? AppTheme.successColor : AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${p['price']} جنيه',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Semantics(label: 'تفاصيل مقدم الخدمة',
                  child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderDetailsScreen(providerId: p['id'].toString()),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('البروفايل', style: TextStyle(fontSize: 12)),
                  ),
                ),
                ),
                SizedBox(height: 8.h),
                Semantics(label: 'احجز',
                  child: GestureDetector(
                  onTap: () => _selectProviderAndBook(p),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('احجز', style: TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showProviderSelection(bool isScheduled) {
    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مقدمي خدمة حالياً')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(DesignTokens.space12),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              isScheduled ? 'حدد مقدم الخدمة والموعد' : 'اختر مقدم الخدمة',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.builder(
                itemCount: _providers.length,
                itemBuilder: (ctx, index) {
                  final p = _providers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text(p['name'][0], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p['name'] ?? ''),
                    subtitle: Text('${p['price']} جنيه'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _selectProviderAndBook(p, isScheduled: isScheduled);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectProviderAndBook(Map<String, dynamic> provider, {bool isScheduled = false}) async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن تحديد موقعك، تأكد من تفعيل GPS')),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientCheckoutScreen(
              serviceId: widget.serviceId,
              serviceName: widget.serviceName,
              categoryId: widget.categoryId,
              price: provider['price']?.toString() ?? '0',
              isNow: false, // Default to scheduled for direct booking
              location: LatLng(position.latitude, position.longitude),
        ),
      ),
      ),
    );
  }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }
}
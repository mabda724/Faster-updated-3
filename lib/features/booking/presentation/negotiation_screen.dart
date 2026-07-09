import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import 'tracking_screen.dart';

class NegotiationScreen extends StatefulWidget {
  final String bookingId;
  final String serviceName;
  final double totalPrice;
  final List<Map<String, dynamic>> offers;

  const NegotiationScreen({
    super.key,
    required this.bookingId,
    required this.serviceName,
    required this.totalPrice,
    required this.offers,
  });

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  bool _showChat = false;
  String _selectedProviderId = '';
  String _selectedProviderName = '';
  String _selectedPrice = '';
  final _chatController = TextEditingController();

  List<Map<String, dynamic>> get _providers {
    return widget.offers.map((offer) {
      final provider = offer['provider'] ?? {};
      final profiles = provider['profiles'] ?? {};
      return {
        'provider_id': offer['provider_id'] ?? '',
        'name': profiles['full_name'] ?? 'مقدم خدمة',
        'image': profiles['avatar_url'] as String? ?? '',
        'rating': (provider['rating'] ?? 0.0).toDouble(),
        'reviews': 0,
        'price': (offer['offered_price'] ?? widget.totalPrice).toString(),
        'profession': provider['profession'] ?? '',
        'is_verified': profiles['is_verified'] == true,
        'phone': profiles['phone'] as String?,
      };
    }).toList();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _goToChat(String providerId, String name, String price) {
    setState(() {
      _selectedProviderId = providerId;
      _selectedProviderName = name;
      _selectedPrice = price;
      _showChat = true;
    });
  }

  Future<void> _acceptOffer(Map<String, dynamic> provider) async {
    final providerId = provider['provider_id'] as String;
    final price = provider['price'] as String;
    try {
      await SupabaseService.db
          .from('bookings')
          .update({
            'provider_id': providerId,
            'status': 'accepted',
            'total_price': double.tryParse(price) ?? widget.totalPrice,
            'commission_amount': (double.tryParse(price) ?? widget.totalPrice) * 0.1,
            'commission_rate': 0.1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.bookingId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TrackingScreen(bookingId: widget.bookingId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting offer: $e');
    }
  }

  Future<void> _confirmNegotiation() async {
    try {
      await SupabaseService.db
          .from('bookings')
          .update({
            'provider_id': _selectedProviderId.isNotEmpty ? _selectedProviderId : null,
            'status': 'accepted',
            'total_price':
                double.tryParse(_selectedPrice) ?? widget.totalPrice,
            'commission_amount': (double.tryParse(_selectedPrice) ?? widget.totalPrice) * 0.1,
            'commission_rate': 0.1,
            'updated_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.bookingId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TrackingScreen(bookingId: widget.bookingId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error confirming negotiation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showChat) return _buildChatScreen();
    return _buildOffersScreen();
  }

  // ============================================================
  // OFFERS SCREEN
  // ============================================================
  Widget _buildOffersScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildOffersHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(DesignTokens.space8.w),
                child: Column(
                  children: [
                    Text(
                      'تلقيت عروضاً جديدة لطلب "${widget.serviceName}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space6.h),
                    ...List.generate(_providers.length, (i) {
                      final p = _providers[i];
                      return _buildOfferCard(p);
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceColor70, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32.sp,
              height: 32.sp,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textPrimary,
                size: 20.sp,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'العروض المتاحة (${_providers.length})',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkSurfaceColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 32.sp),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> provider) {
    final name = provider['name'] as String;
    final image = provider['image'] as String;
    final rating = (provider['rating'] as num).toDouble();
    final reviews = provider['reviews'] as int;
    final price = provider['price'] as String;
    final profession = provider['profession'] as String? ?? '';
    final isVerified = provider['is_verified'] == true;
    final phone = provider['phone'] as String?;

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space4.h),
      padding: EdgeInsets.all(DesignTokens.space6.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor70.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
        border: Border.all(color: AppTheme.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24.sp,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: image.isNotEmpty
                        ? NetworkImage(image)
                        : null,
                    child: image.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'م',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: DesignTokens.space3.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (isVerified) ...[
                            SizedBox(width: DesignTokens.space1.w),
                            Icon(
                              Icons.verified_rounded,
                              color: AppTheme.primaryColor,
                              size: 14.sp,
                            ),
                          ],
                        ],
                      ),
                      if (profession.isNotEmpty)
                        Text(
                          profession,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: AppTheme.warningColor,
                              size: 12.sp),
                          SizedBox(width: DesignTokens.space1.w),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10.sp,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'السعر المقترح',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Text(
                    '$price ج.م',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkBackgroundColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space3.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _goToChat(
                    provider['provider_id'] as String,
                    name,
                    '$price ج.م',
                  ),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(vertical: DesignTokens.space3.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd.r),
                      border: Border.all(color: AppTheme.darkBackgroundColor),
                    ),
                    child: Center(
                      child: Text(
                        'تفاوض على السعر',
                        style: TextStyle(
                          color: AppTheme.darkBackgroundColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: DesignTokens.space2.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => _acceptOffer(provider),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(vertical: DesignTokens.space3.h),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackgroundColor,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd.r),
                    ),
                    child: Center(
                      child: Text(
                        'قبول العرض',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (phone != null) ...[
            SizedBox(height: DesignTokens.space2.h),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:$phone')),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: DesignTokens.space2.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      color: AppTheme.primaryColor,
                      size: 14.sp,
                    ),
                    SizedBox(width: DesignTokens.space1.w),
                    Text(
                      'اتصال',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CHAT SCREEN
  // ============================================================
  Widget _buildChatScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildChatHeader(),
            Expanded(
              child: Container(
                color: AppTheme.surfaceColor70.withValues(alpha: 0.5),
                child: ListView(
                  padding: EdgeInsets.all(DesignTokens.space8.w),
                  children: [
                    _buildProviderMessage(
                      'مرحباً بك يا فندم، قرأت تفاصيل المشكلة وأقترح أن تكون التكلفة الإجمالية شاملة الفحص والصيانة هي $_selectedPrice.',
                    ),
                    SizedBox(height: DesignTokens.space4.h),
                    _buildClientMessage(
                      'هل يمكن أن نصل لاتفاق على سعر 90 ج.م؟ المكان قريب جداً والمشكلة بسيطة.',
                    ),
                    SizedBox(height: DesignTokens.space4.h),
                    _buildProviderPriceUpdate(),
                  ],
                ),
              ),
            ),
            _buildChatBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.backgroundColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showChat = false),
            child: Container(
              width: 32.sp,
              height: 32.sp,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textPrimary,
                size: 20.sp,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'تفاوض مع $_selectedProviderName',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkSurfaceColor,
                  ),
                ),
                Text(
                  'نشط الآن',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 32.sp),
        ],
      ),
    );
  }

  Widget _buildProviderMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.sp),
        padding: EdgeInsets.all(DesignTokens.space6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignTokens.radiusLg.r),
            topRight: Radius.circular(DesignTokens.radiusLg.r),
            bottomLeft: Radius.circular(DesignTokens.radiusLg.r),
            bottomRight: Radius.zero,
          ),
          border: Border.all(color: AppTheme.backgroundColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildClientMessage(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.sp),
        padding: EdgeInsets.all(DesignTokens.space6.w),
        decoration: BoxDecoration(
          color: AppTheme.darkBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.zero,
            topRight: Radius.circular(DesignTokens.radiusLg.r),
            bottomLeft: Radius.circular(DesignTokens.radiusLg.r),
            bottomRight: Radius.circular(DesignTokens.radiusLg.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderPriceUpdate() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.sp),
        padding: EdgeInsets.all(DesignTokens.space6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignTokens.radiusLg.r),
            topRight: Radius.circular(DesignTokens.radiusLg.r),
            bottomLeft: Radius.circular(DesignTokens.radiusLg.r),
            bottomRight: Radius.zero,
          ),
          border: Border.all(color: AppTheme.backgroundColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تمام يا فندم، الله المستعان، تم تعديل السعر المتفق عليه إلى:',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: DesignTokens.space3.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(DesignTokens.space4.w),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
              ),
              child: Column(
                children: [
                  Text(
                    'السعر المحدث',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  Text(
                    '90 ج.م',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkBackgroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBottom() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.backgroundColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    controller: _chatController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'اكتب عرضك أو رسالتك هنا...',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.space6.w,
                        vertical: DesignTokens.space3.h,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: DesignTokens.space2.w),
              Container(
                width: 36.sp,
                height: 36.sp,
                decoration: const BoxDecoration(
                  color: AppTheme.darkBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 14.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space3.h),
          GestureDetector(
            onTap: _confirmNegotiation,
            child: Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(vertical: DesignTokens.space4.h),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'تأكيد السعر المحدث وبدء الرحلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

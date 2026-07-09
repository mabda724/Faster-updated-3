import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  String _storeName = '';
  int _totalProducts = 0;
  double _totalSales = 0;
  int _activeOrders = 0;
  double _walletBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .single();
      _storeName = profile['full_name'] ?? '';

      final pp = await SupabaseService.db
          .from('provider_profiles')
          .select('wallet_balance')
          .eq('id', uid)
          .maybeSingle();
      if (pp != null) {
        _walletBalance =
            double.tryParse(pp['wallet_balance']?.toString() ?? '0') ?? 0;
      }

      final products = await SupabaseService.db
          .from('products')
          .select('id, price')
          .eq('provider_id', uid);
      _totalProducts = products.length;
      _totalSales = products.fold<double>(
          0, (sum, p) => sum + (p['price'] as num? ?? 0).toDouble());

      final active = await SupabaseService.db
          .from('bookings')
          .select('id')
          .eq('provider_id', uid)
          .inFilter('status',
              ['pending', 'accepted', 'on_the_way', 'arrived', 'in_progress']);
      _activeOrders = active.length;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Seller dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space24,
                    vertical: DesignTokens.space16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: DesignTokens.space24),
                      _buildWalletCard(),
                      SizedBox(height: DesignTokens.space24),
                      _buildStatsGrid(),
                      SizedBox(height: DesignTokens.space24),
                      _buildQuickActions(),
                      SizedBox(height: DesignTokens.space24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space24,
        DesignTokens.space16,
        DesignTokens.space24,
        DesignTokens.space24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.darkBackgroundColor,
            AppTheme.darkSurfaceColor,
            AppTheme.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(DesignTokens.radius2xl),
          bottomRight: Radius.circular(DesignTokens.radius2xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحبا بك،',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: DesignTokens.textBodySmall.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: DesignTokens.space2),
                    Text(
                      _storeName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.textTitleLarge.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.2),
                  borderRadius: DesignTokens.brMd,
                  border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'متجر نشط',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.textBodySmall.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: DesignTokens.brXl,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'رصيد المحفظة',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(
                '${_walletBalance.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: DesignTokens.space12,
      mainAxisSpacing: DesignTokens.space12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'عدد المنتجات',
          '$_totalProducts',
          Icons.inventory_2_rounded,
          AppTheme.infoColor,
        ),
        _buildStatCard(
          'إجمالي المبيعات',
          '${_totalSales.toStringAsFixed(0)} ج.م',
          Icons.monetization_on_rounded,
          AppTheme.successColor,
        ),
        _buildStatCard(
          'الطلبات النشطة',
          '$_activeOrders',
          Icons.receipt_long_rounded,
          AppTheme.warningColor,
        ),
        _buildStatCard(
          'الأرباح',
          '${(_walletBalance).toStringAsFixed(0)} ج.م',
          Icons.trending_up_rounded,
          AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brXl,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: DesignTokens.space8),
          Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.textTitleMedium.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: DesignTokens.space1),
          Text(
            label,
            style: const TextStyle(
              fontSize: DesignTokens.textBodySmall,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: DesignTokens.textTitleMedium.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'إدارة المنتجات',
                Icons.inventory_2_rounded,
                AppTheme.infoColor,
                () {},
              ),
            ),
            SizedBox(width: DesignTokens.space12),
            Expanded(
              child: _buildActionCard(
                'الطلبات',
                Icons.receipt_long_rounded,
                AppTheme.warningColor,
                () {},
              ),
            ),
          ],
        ),
        SizedBox(height: DesignTokens.space12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'المحفظة',
                Icons.account_balance_wallet_rounded,
                AppTheme.successColor,
                () {},
              ),
            ),
            SizedBox(width: DesignTokens.space12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.space16, vertical: DesignTokens.space16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DesignTokens.brXl,
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: DesignTokens.space8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: DesignTokens.textBodyLarge.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.textTertiary, size: 14),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class ProviderPerformanceScreen extends StatefulWidget {
  const ProviderPerformanceScreen({super.key});
  @override
  State<ProviderPerformanceScreen> createState() =>
      _ProviderPerformanceScreenState();
}

class _ProviderPerformanceScreenState
    extends State<ProviderPerformanceScreen> {
  bool _isLoading = true;
  double _rating = 0;
  int _totalRatings = 0;
  double _acceptanceRate = 0;
  double _cancelRate = 0;
  int _completedThisMonth = 0;
  int _bonusProgress = 0;
  int _bonusTarget = 100;
  double _bonusAmount = 150;
  String _rankingLabel = 'كابتن';
  String _rankingPercentile = '';
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      // Provider rating
      final prov = await SupabaseService.db
          .from('provider_profiles')
          .select('rating, average_rating')
          .eq('id', uid)
          .maybeSingle();
      if (prov != null) {
        _rating = double.tryParse(
                (prov['average_rating'] ?? prov['rating'] ?? '0')
                    .toString()) ??
            0;
      }

      // Review count
      final countRes = await SupabaseService.db
          .from('reviews')
          .select('id')
          .eq('provider_id', uid);
      _totalRatings = countRes.length;

      // Reviews with client data
      final revRes = await SupabaseService.db
          .from('reviews')
          .select(
              'rating, comment, created_at, profiles!reviews_client_id_fkey(full_name)')
          .eq('provider_id', uid)
          .order('created_at', ascending: false)
          .limit(20);
      _reviews = List<Map<String, dynamic>>.from(revRes);

      // Booking stats
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthStartStr = monthStart.toIso8601String();

      final allRes = await SupabaseService.db
          .from('bookings')
          .select('status')
          .eq('provider_id', uid);
      final allCount = allRes.length;
      var cancelledCount = 0;
      var completedCount = 0;
      var acceptedCount = 0;
      for (var b in allRes) {
        final s = b['status']?.toString() ?? '';
        if (s == 'completed') completedCount++;
        if (s == 'cancelled') cancelledCount++;
        if (s == 'accepted' ||
            s == 'on_the_way' ||
            s == 'arrived' ||
            s == 'in_progress' ||
            s == 'completed') acceptedCount++;
      }
      final totalOffered = acceptedCount + cancelledCount;
      _acceptanceRate = totalOffered > 0
          ? (acceptedCount / totalOffered * 100).clamp(0, 100)
          : 0;
      _cancelRate =
          acceptedCount > 0 ? (cancelledCount / acceptedCount * 100) : 0;

      // This month completed
      final monthRes = await SupabaseService.db
          .from('bookings')
          .select('id')
          .eq('provider_id', uid)
          .eq('status', 'completed')
          .gte('created_at', monthStartStr);
      _completedThisMonth = monthRes.length;

      // Bonus logic: 100 rides target, 150 EGP bonus
      _bonusTarget = 100;
      _bonusAmount = 150;
      _bonusProgress = _completedThisMonth > _bonusTarget
          ? _bonusTarget
          : _completedThisMonth;

      // Ranking
      if (_rating >= 4.8) {
        _rankingLabel = 'كابتن ماسي مميز';
        _rankingPercentile = 'أنت ضمن أفضل 5% من الكباتن هذا الشهر';
      } else if (_rating >= 4.5) {
        _rankingLabel = 'كابتن ذهبي';
        _rankingPercentile = 'أنت ضمن أفضل 15% من الكباتن هذا الشهر';
      } else if (_rating >= 4.0) {
        _rankingLabel = 'كابتن فضي';
        _rankingPercentile = 'أداء جيد مستمر';
      } else {
        _rankingLabel = 'كابتن';
        _rankingPercentile = 'حافظ على أدائك للارتقاء للتصنيف الأعلى';
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Performance load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      final months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: 16),
                    _buildBonusBar(),
                    const SizedBox(height: 20),
                    _buildReviewsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.darkBackgroundColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              const Text(
                'أدائي وتقييماتي',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rating card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تصنيفك الحالي في Faster',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 16, color: AppTheme.warningColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _rankingLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _rankingPercentile,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppTheme.warningColor),
                        ],
                      ),
                      const Text(
                        'من 5.0',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final acceptanceLabel = _acceptanceRate >= 90
        ? 'ممتاز'
        : _acceptanceRate >= 70
            ? 'جيد'
            : 'بحاجة تحسين';
    final acceptanceBadgeColor = _acceptanceRate >= 90
        ? AppTheme.successColor
        : _acceptanceRate >= 70
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final acceptanceBgColor = _acceptanceRate >= 90
        ? AppTheme.backgroundColor
        : _acceptanceRate >= 70
            ? AppTheme.surfaceColor
            : AppTheme.backgroundColor;

    final cancelLabel = _cancelRate < 5
        ? 'آمن جداً'
        : _cancelRate < 15
            ? 'مقبول'
            : 'مرتفع';
    final cancelBadgeColor = _cancelRate < 5
        ? AppTheme.successColor
        : _cancelRate < 15
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final cancelBgColor = _cancelRate < 5
        ? AppTheme.backgroundColor
        : _cancelRate < 15
            ? AppTheme.surfaceColor
            : AppTheme.backgroundColor;

    return Row(
      children: [
        _statCard(
          'قبول الطلبات',
          '${_acceptanceRate.toStringAsFixed(0)}%',
          acceptanceLabel,
          acceptanceBadgeColor,
          acceptanceBgColor,
        ),
        const SizedBox(width: 8),
        _statCard(
          'معدل الإلغاء',
          '${_cancelRate.toStringAsFixed(1)}%',
          cancelLabel,
          cancelBadgeColor,
          cancelBgColor,
        ),
        const SizedBox(width: 8),
        _statCard(
          'رحلات ناجحة',
          '$_completedThisMonth',
          'هذا الشهر',
          AppTheme.primaryColor,
          AppTheme.backgroundColor,
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    String badge,
    Color badgeColor,
    Color badgeBg,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusBar() {
    final remaining = _bonusTarget - _completedThisMonth;
    final progressPercent = (_bonusProgress / _bonusTarget * 100).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'هدفك للمكافأة الأسبوعية القادمة',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '$_completedThisMonth / $_bonusTarget رحلة',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            remaining > 0
                ? 'أكمل $remaining رحلة إضافية للحصول على بونص بقيمة $_bonusAmount جنيه.'
                : 'أحسنت! لقد حققت الهدف الأسبوعي!',
            style: TextStyle(
              fontSize: 9,
              color: remaining > 0
                  ? AppTheme.textTertiary
                  : AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'أحدث آراء العملاء والمتاجر',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'آخر 30 يوم',
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 40,
                      color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  const Text(
                    'لا توجد تقييمات بعد',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ..._reviews.map(_buildReviewItem),
      ],
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> r) {
    final intRating = int.tryParse(r['rating']?.toString() ?? '5') ?? 5;
    final clientName = r['profiles']?['full_name']?.toString() ?? 'عميل';
    final comment = r['comment']?.toString();
    final createdAt = r['created_at']?.toString();
    final dateStr = _formatDate(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_rounded,
                        size: 12, color: AppTheme.errorColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$clientName (عميل)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < intRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 10,
                    color: i < intRating
                        ? AppTheme.warningColor
                        : AppTheme.borderColor,
                  );
                }),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"$comment"',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 8,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

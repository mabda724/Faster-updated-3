import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class ReviewsScreen extends StatefulWidget {
  final String? providerId;
  final String? bookingId;

  const ReviewsScreen({super.key, this.providerId, this.bookingId});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0;
  final Map<int, int> _ratingBreakdown = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  int _rating = 0;
  int _serviceQuality = 0;
  int _punctuality = 0;
  int _communication = 0;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null) {
      _loadReview();
    } else if (widget.providerId != null) {
      _loadProviderReviews();
    }
  }

  Future<void> _loadReview() async {
    try {
      final review = await SupabaseService.db
          .from('reviews')
          .select('*')
          .eq('booking_id', widget.bookingId.toString())
          .maybeSingle();

      if (review != null && mounted) {
        setState(() {
          _reviews = [review];
        });
      }
    } catch (e) {
      debugPrint('Error loading review: $e');
    }
  }

  Future<void> _loadProviderReviews() async {
    if (widget.providerId == null) return;
    setState(() => _isLoading = true);

    try {
      final data = await SupabaseService.db
          .from('reviews')
          .select('*, profiles!reviews_client_id_fkey(full_name, avatar_url)')
          .eq('provider_id', widget.providerId.toString())
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(data);
          _calculateStats();
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    _ratingBreakdown.addAll({1: 0, 2: 0, 3: 0, 4: 0, 5: 0});
    if (_reviews.isEmpty) return;

    double total = 0;
    for (var review in _reviews) {
      total += (review['rating'] ?? 0);
      final rating = review['rating'] ?? 0;
      _ratingBreakdown[rating] = (_ratingBreakdown[rating] ?? 0) + 1;
    }
    _averageRating = total / _reviews.length;
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('حسناً'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      _showAlert('تنبيه', 'الرجاء اختيار تقييم عام');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bookingId = widget.bookingId;
      final providerId = widget.providerId;
      final clientId = SupabaseService.currentUserId;

      if (bookingId == null || providerId == null || clientId == null) {
        _showAlert('خطأ', 'معلومات غير كافية');
        setState(() => _isLoading = false);
        return;
      }

      await SupabaseService.db.from('reviews').insert({
        'booking_id': bookingId,
        'provider_id': providerId,
        'client_id': clientId,
        'rating': _rating,
        'service_quality': _serviceQuality > 0 ? _serviceQuality : null,
        'punctuality': _punctuality > 0 ? _punctuality : null,
        'communication': _communication > 0 ? _communication : null,
        'comment': _commentCtrl.text.trim().isNotEmpty ? _commentCtrl.text.trim() : null,
      });

      if (mounted) {
        _showAlert('تم', 'شكراً لك على تقييمك!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showAlert('خطأ', 'فشل في إرسال التقييم: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWriteMode = widget.bookingId != null;
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: isWriteMode ? _buildWriteReview(theme) : _buildReviewList(theme),
    );
  }

  Widget _buildWriteReview(theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRatingInput(theme),
        SizedBox(height: DesignTokens.space24),
        _buildDetailedRatings(theme),
        SizedBox(height: DesignTokens.space24),
        _buildCommentInput(theme),
        SizedBox(height: DesignTokens.space32),
        _buildSubmitButton(theme),
      ],
    );
  }

  Widget _buildRatingInput(theme) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: DesignTokens.br2xl,
      ),
      child: Column(
        children: [
          Text(
            'كيف كانت تجربتك؟',
            style: TextStyle(
              fontSize: DesignTokens.textTitleMedium,
              fontWeight: FontWeight.bold,
              color: theme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _rating = index + 1),
                child: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_rounded,
                  color: index < _rating ? AppTheme.warningColor : Colors.grey.shade300,
                  size: 48,
                ),
              );
            }),
          ),
          if (_rating > 0)
            Padding(
              padding: EdgeInsets.only(top: DesignTokens.space8),
              child: Text(
                _getRatingText(_rating),
                style: TextStyle(
                  fontSize: DesignTokens.textBodyLarge,
                  fontWeight: FontWeight.w600,
                  color: theme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedRatings(theme) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: DesignTokens.brXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل التقييم',
            style: TextStyle(
              fontSize: DesignTokens.textTitleSmall,
              fontWeight: FontWeight.bold,
              color: theme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.space16),
          _buildDetailedRatingRow('جودة الخدمة', _serviceQuality, (v) => setState(() => _serviceQuality = v), theme),
          _buildDetailedRatingRow('الالتزام بالوقت', _punctuality, (v) => setState(() => _punctuality = v), theme),
          _buildDetailedRatingRow('التواصل', _communication, (v) => setState(() => _communication = v), theme),
        ],
      ),
    );
  }

  Widget _buildDetailedRatingRow(String label, int value, ValueChanged<int> onChanged, theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: DesignTokens.space16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.textBodyMedium,
              color: theme.onSurface.withOpacity(0.7),
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onChanged(index + 1),
                child: Icon(
                  index < value ? Icons.star_rounded : Icons.star_rounded,
                  color: index < value ? AppTheme.warningColor : Colors.grey.shade300,
                  size: 20,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: DesignTokens.brLg,
      ),
      child: TextField(
        controller: _commentCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'أضف تعليقاً (اختياري)',
        ),
        style: TextStyle(fontSize: DesignTokens.textBodyLarge),
      ),
    );
  }

  Widget _buildSubmitButton(theme) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitReview,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
          backgroundColor: theme.primary,
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                'إرسال التقييم',
                style: TextStyle(
                  fontSize: DesignTokens.textLabelLarge,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildReviewList(theme) {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_rounded, size: 64, color: Colors.grey.shade300),
            SizedBox(height: DesignTokens.space16),
            Text(
              'لا توجد تقييمات بعد',
              style: TextStyle(fontSize: DesignTokens.textTitleMedium, color: theme.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats header
        Container(
          padding: EdgeInsets.all(DesignTokens.space20),
          margin: EdgeInsets.only(bottom: DesignTokens.space24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: DesignTokens.brXl,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.primary,
                    ),
                  ),
                  SizedBox(width: DesignTokens.space12),
                  Column(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < _averageRating.round() ? Icons.star_rounded : Icons.star_rounded,
                            color: AppTheme.warningColor,
                            size: 16,
                          );
                        }),
                      ),
                      SizedBox(height: DesignTokens.space2),
                      Text(
                        '${_reviews.length} تقييم',
                        style: TextStyle(fontSize: 12, color: theme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.space8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 4, 3, 2, 1].map((star) {
                  final count = _ratingBreakdown[star] ?? 0;
                  final percentage = _reviews.isEmpty ? 0 : (count / _reviews.length * 100);
                  return Column(
                    children: [
                      Text('$star'),
                      Container(
                        width: 30,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: percentage / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Reviews list
        ..._reviews.map((review) => _buildReviewCard(review, theme)).toList(),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, theme) {
    final client = review['profiles'] as Map<String, dynamic>?;
    final name = client?['full_name'] ?? 'مستخدم';
    final avatarUrl = client?['avatar_url'];
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? '';
    final date = review['created_at'] != null
        ? DateTime.parse(review['created_at']).toLocal()
        : DateTime.now();

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space16),
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        boxShadow: [
          BoxShadow(
            color: theme.onBackground.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? Icon(Icons.person_rounded, color: Colors.grey) : null,
              ),
              SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.textBodyLarge,
                        color: theme.onSurface,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star_rounded : Icons.star_rounded,
                          color: AppTheme.warningColor,
                          size: 12,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(date.toString()),
                style: TextStyle(
                  fontSize: DesignTokens.textLabelSmall,
                  color: theme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: DesignTokens.space12),
            Text(
              comment,
              style: TextStyle(
                fontSize: DesignTokens.textBodyMedium,
                color: theme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'سيء جداً';
      case 2:
        return 'سيء';
      case 3:
        return 'جيد';
      case 4:
        return 'جيد جداً';
      case 5:
        return 'ممتاز';
      default:
        return '';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }
}

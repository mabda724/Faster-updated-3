import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';

class ImmediateRatingDialog extends StatefulWidget {
  final String providerName;
  final Function(int rating, String comment) onSubmit;
  final VoidCallback? onSkip;

  const ImmediateRatingDialog({
    super.key,
    required this.providerName,
    required this.onSubmit,
    this.onSkip,
  });

  @override
  State<ImmediateRatingDialog> createState() => _ImmediateRatingDialogState();
}

class _ImmediateRatingDialogState extends State<ImmediateRatingDialog>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentCtrl = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String _getRatingText(int r) {
    switch (r) {
      case 1:
        return 'سيء جداً';
      case 2:
        return 'سيء';
      case 3:
        return 'مقبول';
      case 4:
        return 'جيد جداً';
      case 5:
        return 'ممتاز!';
      default:
        return 'اضغط على النجوم للتقييم';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.successColor,
                size: 36,
              ),
            ),
            SizedBox(height: DesignTokens.space16),
            Text(
              'تم إتمام الخدمة بنجاح!',
              style: TextStyle(
                fontSize: DesignTokens.textTitleLarge,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.space4),
            Text(
              'كيف كانت تجربتك مع ${widget.providerName}؟',
              style: TextStyle(
                fontSize: DesignTokens.textBodyMedium,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.space20),
            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return Semantics(
                  label: 'تقييم $starIndex من 5',
                  child: GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: AnimatedScale(
                      scale: starIndex <= _rating ? 1.2 : 1.0,
                      duration: DesignTokens.durationFast,
                      child: Icon(
                        starIndex <= _rating
                            ? Icons.star_rounded
                            : Icons.star_rounded,
                        color: AppTheme.tertiaryColor,
                        size: 44,
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: DesignTokens.space8),
            Text(
              _getRatingText(_rating),
              style: TextStyle(
                fontSize: DesignTokens.textBodyLarge,
                fontWeight: FontWeight.bold,
                color: _rating > 0 ? AppTheme.tertiaryColor : AppTheme.textSecondary,
              ),
            ),
            if (_rating > 0) ...[
              SizedBox(height: DesignTokens.space12),
              TextField(
                controller: _commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'أضف تعليقك (اختياري)...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(DesignTokens.space12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: const Text('لاحقاً'),
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            onPressed: _rating > 0
                ? () => widget.onSubmit(_rating, _commentCtrl.text.trim())
                : null,
            child: Text(
              widget.onSkip == null ? 'تقييم إجباري - اضغط النجوم' : 'إرسال التقييم',
            ),
          ),
        ],
      ),
    );
  }
}

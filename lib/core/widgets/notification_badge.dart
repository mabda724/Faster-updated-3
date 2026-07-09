import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/notification_badge_service.dart';
import '../theme/app_theme.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;
  final double size;

  const NotificationBadge({
    super.key,
    required this.child,
    this.badgeColor,
    this.textColor,
    this.size = 18,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _lastCount = NotificationBadgeService().unreadCount;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerFlash() {
    _animationController.forward().then((_) => _animationController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationBadgeService().badgeStream,
      initialData: NotificationBadgeService().unreadCount,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.child;
        }
        final count = snapshot.data ?? 0;
        
        if (count > _lastCount) {
          _triggerFlash();
        }
        _lastCount = count;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (count > 0)
              Positioned(
                right: -6.w,
                top: -6.h,
                child: ListenableBuilder(
                  listenable: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_animationController.value * 0.3),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    constraints: BoxConstraints(minWidth: widget.size, minHeight: widget.size),
                    decoration: BoxDecoration(
                      color: widget.badgeColor ?? AppTheme.errorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.badgeColor ?? AppTheme.errorColor).withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: TextStyle(
                        color: widget.textColor ?? Colors.white,
                        fontSize: widget.size * 0.6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class NotificationBell extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? iconColor;
  final double iconSize;

  const NotificationBell({
    super.key,
    this.onTap,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationBadge(
      child: IconButton(
        onPressed: onTap ?? () => Navigator.pushNamed(context, '/notifications'),
        icon: Icon(
          Icons.notifications_outlined,
          color: iconColor ?? AppTheme.surfaceColor,
          size: iconSize,
        ),
        tooltip: 'الإشعارات',
      ),
    );
  }
}
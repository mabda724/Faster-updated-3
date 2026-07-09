import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import 'register_screen.dart';
import 'partner_type_selection_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const List<Map<String, dynamic>> _roles = [
    {
      'role': 'client',
      'label': 'عميل',
      'icon': Icons.person_rounded,
    },
    {
      'role': 'admin',
      'label': 'ادمن',
      'icon': Icons.settings_rounded,
    },
    {
      'role': 'developer',
      'label': 'مطور',
      'icon': Icons.build_rounded,
    },
    {
      'role': 'partner',
      'label': 'شريك',
      'icon': Icons.business_rounded,
    },
  ];

  void _onRoleTap(BuildContext context, String role) {
    if (role == 'partner') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PartnerTypeSelectionScreen(),
          fullscreenDialog: true,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(role: role),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      const backgroundColor: Colors.white,
        border: null,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.space8),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              final roleData = _roles[index];
              final role = roleData['role'] as String;
              final label = roleData['label'] as String;
              final icon = roleData['icon'] as IconData;

              return ElevatedButton(
                padding: EdgeInsets.zero,
                onPressed: () => _onRoleTap(context, role),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textPrimary.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(DesignTokens.space6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withOpacity(0.15),
                        ),
                        child: Icon(
                          icon,
                          size: DesignTokens.iconXl,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: DesignTokens.space6),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: DesignTokens.textTitleSmall,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

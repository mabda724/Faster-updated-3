import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import 'register_screen.dart';

class PartnerTypeSelectionScreen extends StatefulWidget {
  const PartnerTypeSelectionScreen({super.key});

  @override
  State<PartnerTypeSelectionScreen> createState() => _PartnerTypeSelectionScreenState();
}

class _PartnerTypeSelectionScreenState extends State<PartnerTypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _partnerTypes = [
    {
      'role': 'provider',
      'label': 'مقدم خدمة',
      'description': 'قدم خدمات منزلية مميزة مثل الصيانة والت清洁 والنجارة',
      'icon': Icons.home_repair_service_rounded,
      'color': AppTheme.successColor,
      'gradient': [AppTheme.successColor, AppTheme.successColor],
    },
    {
      'role': 'seller',
      'label': 'تاجر',
      'description': 'اعرض منتجاتك وبيها عبر المتجر الرقمي',
      'icon': Icons.shopping_bag_rounded,
      'color': AppTheme.tertiaryColor,
      'gradient': [AppTheme.tertiaryColor, AppTheme.warningColor],
    },
    {
      'role': 'driver',
      'label': 'سائق',
      'description': 'قدم خدمات النقل والرحلات للعملاء',
      'icon': Icons.drive_eta_rounded,
      'color': AppTheme.primaryColor,
      'gradient': [AppTheme.primaryColor, AppTheme.infoColor],
    },
    {
      'role': 'delivery',
      'label': 'سائق دليفري',
      'description': 'استقبل طلبات التوصيل وأنجزها بسرعة وأمان',
      'icon': Icons.local_shipping_rounded,
      'color': AppTheme.primaryColor,
      'gradient': [AppTheme.primaryColor, AppTheme.primaryColor],
    },
  ];

  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOut,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    setState(() => _selectedIndex = index);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              role: _partnerTypes[index]['role'] as String,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.08),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView(
                    padding: EdgeInsets.all(DesignTokens.space16),
                    children: [
                      _buildHeader(),
                      SizedBox(height: DesignTokens.space24),
                      ...List.generate(_partnerTypes.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: DesignTokens.space12),
                          child: _buildPartnerCard(index),
                        );
                      }),
                      SizedBox(height: DesignTokens.space16),
                      _buildBackButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space4,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(DesignTokens.space2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: DesignTokens.shadow1(Colors.black),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'اختر نوع partnership',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: DesignTokens.textTitleMedium,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.brXl,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.space6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_center_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          SizedBox(height: DesignTokens.space12),
          Text(
            'انضم كشريك',
            style: GoogleFonts.cairo(
              fontSize: DesignTokens.textTitleLarge,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: DesignTokens.space4),
          Text(
            'اختر نوع partnership الذي يناسبك',
            style: GoogleFonts.cairo(
              fontSize: DesignTokens.textBodyMedium,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(int index) {
    final data = _partnerTypes[index];
    final isSelected = _selectedIndex == index;
    final color = data['color'] as Color;
    final gradient = data['gradient'] as List<Color>;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(index),
          borderRadius: DesignTokens.brLg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
              borderRadius: DesignTokens.brLg,
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : DesignTokens.shadow1(Colors.black),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: DesignTokens.brMd,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    data['icon'] as IconData,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['label'] as String,
                        style: GoogleFonts.cairo(
                          fontSize: DesignTokens.textBodyLarge,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: DesignTokens.space1),
                      Text(
                        data['description'] as String,
                        style: GoogleFonts.cairo(
                          fontSize: DesignTokens.textBodySmall,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('العودة'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
      ),
    );
  }
}
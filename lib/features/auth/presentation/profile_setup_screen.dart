import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../data/auth_repository.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _authRepo = AuthRepository();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty) {
      _snack('الرجاء إدخال الاسم والمدينة');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) {
        _snack('خطأ في تحميل المستخدم');
        setState(() => _isLoading = false);
        return;
      }

      await SupabaseService().client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      }).eq('id', userId);

      if (!mounted) return;
      _snack('تم حفظ البيانات بنجاح');
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _snack('حدث خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(DesignTokens.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: EdgeInsets.all(DesignTokens.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 80.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: DesignTokens.space24),
                Text(
                  'إكمال الملف الشخصي',
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleLarge,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: DesignTokens.space8),
                Text(
                  'أكمل بياناتك للبدء في استخدام التطبيق',
                  style: TextStyle(
                    fontSize: DesignTokens.textLabelMedium,
                    color: AppTheme.textPrimary.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: DesignTokens.space32),
                Container(
                  padding: EdgeInsets.all(DesignTokens.space16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: DesignTokens.brXl,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 25,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInput(_nameCtrl, 'الاسم الكامل', Icons.person),
                      SizedBox(height: DesignTokens.space16),
                      _buildInput(_cityCtrl, 'المدينة', Icons.location_on),
                      SizedBox(height: DesignTokens.space24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: DesignTokens.space16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: DesignTokens.brLg,
                          ),
                          backgroundColor: AppTheme.primaryColor,
                          disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
                          minimumSize: Size(double.infinity, DesignTokens.buttonHeight),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: DesignTokens.iconSm,
                                height: DesignTokens.iconSm,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'حفظ ومتابعة',
                                style: TextStyle(
                                  fontSize: DesignTokens.textLabelLarge,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: DesignTokens.iconMd),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.all(DesignTokens.space12),
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      style: TextStyle(fontSize: DesignTokens.textBodyLarge),
    );
  }
}

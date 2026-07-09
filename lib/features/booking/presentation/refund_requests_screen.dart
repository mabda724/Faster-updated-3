import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class RefundRequestsScreen extends StatefulWidget {
  final String bookingId;
  const RefundRequestsScreen({super.key, required this.bookingId});

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _refundRequests = [];
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRefundRequests();
  }

  Future<void> _loadRefundRequests() async {
    try {
      final data = await SupabaseService.db
          .from('refund_requests')
          .select('*')
          .eq('booking_id', widget.bookingId)
          .order('created_at', ascending: false);
      
      setState(() {
        _refundRequests = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الطلبات: $e')),
        );
      }
    }
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

  Future<void> _createRefundRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final booking = await SupabaseService.db
          .from('bookings')
          .select('total_price, payment_status')
          .eq('id', widget.bookingId)
          .maybeSingle();
      
      if (booking != null) {
        final amount = double.tryParse(_amountController.text) ?? 0;
        final totalAmount = double.tryParse(booking['total_price'].toString()) ?? 0;
        
        if (amount > totalAmount) {
          if (mounted) {
            _showAlert('خطأ', 'المبلغ المطلوب أكبر من المبلغ الإجمالي');
          }
          return;
        }

        if (booking['payment_status'] == 'paid') {
          await SupabaseService.db.from('refund_requests').insert({
            'booking_id': widget.bookingId,
            'client_id': SupabaseService.currentUserId,
            'amount': amount,
            'reason': _reasonController.text,
            'refund_method': 'bank',
            'bank_account': 'سيتم إضافة البيانات لاحقاً',
          });
          
          if (mounted) {
            _showAlert('تم', 'تم إرسال طلب الاسترداد بنجاح');
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            _showAlert('خطأ', 'لا يمكن طلب استرداد للطلبات غير المدفوعة');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showAlert('خطأ', 'فشل إنشاء الطلب: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Existing refund requests
              if (_refundRequests.isNotEmpty) ...[
                Text(
                  'طلباتك السابقة',
                  style: TextStyle(
                    fontSize: DesignTokens.textTitleMedium,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: DesignTokens.space16),
                ..._refundRequests.map((request) => _buildRefundCard(request)),
                SizedBox(height: DesignTokens.space24),
              ],

              // Create new refund request
              Text(
                'طلب استرداد جديد',
                style: TextStyle(
                  fontSize: DesignTokens.textTitleMedium,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: DesignTokens.space16),

              Container(
                padding: EdgeInsets.all(DesignTokens.space16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.textPrimary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _amountController,
                        label: 'المبلغ المطلوب',
                        hint: 'أدخل المبلغ الذي تريد استرداده',
                        icon: Icons.attach_money_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'حقل مطلوب';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'المبلغ يجب أن يكون أكبر من صفر';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: DesignTokens.space16),
                      _buildTextField(
                        controller: _reasonController,
                        label: 'سبب الطلب',
                        hint: 'اذكر سبب طلبك لاسترداد الأموال',
                        icon: Icons.article_outlined,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'حقل مطلوب';
                          }
                          if (value.trim().length < 10) {
                            return 'يجب أن يكون سبب الطلب مكوناً من 10 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: DesignTokens.space24),
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createRefundRequest,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                          color: AppTheme.primaryColor,
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  'إرسال طلب الاسترداد',
                                  style: TextStyle(
                                    fontSize: DesignTokens.textLabelLarge,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
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

  Widget _buildRefundCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space12),
      padding: EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${request['amount']} جنيه',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textTitleSmall,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space8,
                  vertical: DesignTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: DesignTokens.textLabelSmall,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space8),
          Text(
            request['reason'] ?? '',
            style: TextStyle(
              fontSize: DesignTokens.textBodySmall,
              color: AppTheme.textPrimary.withOpacity(0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: DesignTokens.space8),
          Text(
            'بتاريخ: ${_formatDate(request['created_at'])}',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.textPrimary.withOpacity(0.5),
            ),
          ),
          if (status == 'rejected' && request['admin_note'] != null) ...[
            SizedBox(height: DesignTokens.space8),
            Container(
              padding: EdgeInsets.all(DesignTokens.space8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Text(
                'سبب الرفض: ${request['admin_note']}',
                style: TextStyle(
                  fontSize: DesignTokens.textLabelSmall,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.textBodyLarge,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: DesignTokens.space8),
        TextField(
          controller: controller,
          keyboardType: keyboardType ?? TextInputType.text,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
          ),
          prefix: Padding(
            padding: EdgeInsets.only(right: DesignTokens.space8),
            child: Icon(icon, size: DesignTokens.iconMd, color: AppTheme.textPrimary.withOpacity(0.6)),
          ),
          style: TextStyle(fontSize: DesignTokens.textBodyLarge),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'processing':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'موافق';
      case 'rejected':
        return 'مرفوض';
      case 'processing':
        return 'قيد المعالجة';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} يوم مضت';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ساعة مضت';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} دقيقة مضت';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return dateString;
    }
  }
}
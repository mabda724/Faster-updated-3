import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';

class PrescriptionScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? bookingId;

  const PrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.bookingId,
  });

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addMedicine() {
    setState(() {
      _medicines.add({
        'name': '',
        'dosage': '',
        'frequency': '',
        'duration': '',
        'instructions': '',
      });
    });
  }

  void _removeMedicine(int index) {
    setState(() {
      _medicines.removeAt(index);
    });
  }

  void _updateMedicine(int index, String field, String value) {
    setState(() {
      _medicines[index][field] = value;
    });
  }

  Future<void> _savePrescription() async {
    if (_diagnosisCtrl.text.trim().isEmpty) {
      _showError('الرجاء إدخال التشخيص');
      return;
    }

    if (_medicines.isEmpty) {
      _showError('الرجاء إضافة دواء واحد على الأقل');
      return;
    }

    // Validate medicines
    for (var med in _medicines) {
      if (med['name'].toString().trim().isEmpty ||
          med['dosage'].toString().trim().isEmpty ||
          med['frequency'].toString().trim().isEmpty ||
          med['duration'].toString().trim().isEmpty) {
        _showError('الرجاء ملء جميع حقول الأدوية');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final doctorId = SupabaseService.currentUserId;
      if (doctorId == null) {
        _showError('يجب تسجيل الدخول');
        return;
      }

      // Create prescription
      final prescriptionResult = await SupabaseService.db.rpc('create_prescription', params: {
        'p_doctor_id': doctorId,
        'p_patient_id': widget.patientId,
        'p_booking_id': widget.bookingId,
        'p_diagnosis': _diagnosisCtrl.text.trim(),
        'p_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      if (prescriptionResult == null || prescriptionResult['success'] != true) {
        _showError('فشل إنشاء الروشتة');
        return;
      }

      final prescriptionId = prescriptionResult['prescription_id'];

      // Add medicines
      for (var med in _medicines) {
        await SupabaseService.db.rpc('add_prescription_medicine', params: {
          'p_prescription_id': prescriptionId,
          'p_medicine_name': med['name'].toString().trim(),
          'p_dosage': med['dosage'].toString().trim(),
          'p_frequency': med['frequency'].toString().trim(),
          'p_duration': med['duration'].toString().trim(),
          'p_instructions': med['instructions'].toString().trim().isEmpty ? null : med['instructions'].toString().trim(),
        });
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الروشتة بنجاح'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving prescription: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('حدث خطأ أثناء حفظ الروشتة');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('روشتة إلكترونية'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DesignTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient info card
            Container(
              padding: EdgeInsets.all(DesignTokens.space16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DesignTokens.brXl,
                boxShadow: DesignTokens.shadow2(Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: AppTheme.primaryColor),
                  ),
                  SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المريض: ${widget.patientName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: DesignTokens.space4),
                        Text(
                          'تاريخ: ${DateTime.now().toString().split(' ')[0]}',
                          style: TextStyle(
                            fontSize: DesignTokens.textLabelMedium,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: DesignTokens.space24),

            // Diagnosis
            Text(
              'التشخيص',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textBodyLarge,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: DesignTokens.space8),
            TextField(
              controller: _diagnosisCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب التشخيص هنا...',
                border: OutlineInputBorder(
                  borderRadius: DesignTokens.brLg,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: DesignTokens.space20),

            // Medicines section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الأدوية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: DesignTokens.textBodyLarge,
                    color: AppTheme.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addMedicine,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة دواء'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space12),

            if (_medicines.isEmpty)
              Container(
                padding: EdgeInsets.all(DesignTokens.space24),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.08),
                  borderRadius: DesignTokens.brLg,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.medication, size: DesignTokens.iconAvatar, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                      SizedBox(height: DesignTokens.space8),
                      Text(
                        'لا توجد أدوية مضافة',
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._medicines.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                return _buildMedicineCard(index, med);
              }).toList(),

            SizedBox(height: DesignTokens.space20),

            // Notes
            Text(
              'ملاحظات إضافية (اختياري)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.textBodyLarge,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: DesignTokens.space8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'ملاحظات إضافية...',
                border: OutlineInputBorder(
                  borderRadius: DesignTokens.brLg,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: DesignTokens.space32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: DesignTokens.buttonHeight.h,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePrescription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.brLg,
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'حفظ الروشتة',
                        style: TextStyle(
                          fontSize: DesignTokens.textBodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(int index, Map<String, dynamic> med) {
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.space12),
      padding: EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brLg,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        boxShadow: DesignTokens.shadow2(Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الدواء ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.textBodyMedium,
                  color: AppTheme.primaryColor,
                ),
              ),
              IconButton(
                onPressed: () => _removeMedicine(index),
                icon: Icon(Icons.delete, color: AppTheme.errorColor),
                tooltip: 'حذف',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space12),
          _buildMedicineField(
            'اسم الدواء',
            med['name'] ?? '',
            (value) => _updateMedicine(index, 'name', value),
          ),
          SizedBox(height: DesignTokens.space8),
          Row(
            children: [
              Expanded(
                child: _buildMedicineField(
                  'الجرعة',
                  med['dosage'] ?? '',
                  (value) => _updateMedicine(index, 'dosage', value),
                ),
              ),
              SizedBox(width: DesignTokens.space8),
              Expanded(
                child: _buildMedicineField(
                  'التكرار',
                  med['frequency'] ?? '',
                  (value) => _updateMedicine(index, 'frequency', value),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space8),
          _buildMedicineField(
            'المدة',
            med['duration'] ?? '',
            (value) => _updateMedicine(index, 'duration', value),
          ),
          SizedBox(height: DesignTokens.space8),
          _buildMedicineField(
            'تعليمات (اختياري)',
            med['instructions'] ?? '',
            (value) => _updateMedicine(index, 'instructions', value),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineField(String label, String value, Function(String) onChanged) {
    return TextField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brMd,
        ),
        filled: true,
        fillColor: AppTheme.textSecondary.withValues(alpha: 0.05),
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space8,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

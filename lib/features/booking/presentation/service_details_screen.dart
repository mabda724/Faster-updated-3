import 'dart:io';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/design_tokens.dart';
import 'booking_location_time_screen.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final String serviceName;
  final String imageUrl;
  final String price;
  final double rating;
  final int reviewsCount;
  final String? serviceId;

  const ServiceDetailsScreen({
    super.key,
    required this.serviceName,
    required this.imageUrl,
    required this.price,
    required this.rating,
    required this.reviewsCount,
    this.serviceId,
  });

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  String? _selectedSubService;
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _uploadedImage;
  bool _hasInitialImage = true;

  final _subServices = [
    {'value': '', 'label': 'اختر نوع الخدمة المطلوبة...'},
    {'value': 'leak', 'label': 'إصلاح تسريب مياه'},
    {'value': 'install', 'label': 'تركيب حوض / خلاط مياه'},
    {'value': 'maintenance', 'label': 'صيانة دورية للمواسير'},
    {'value': 'other', 'label': 'أخرى'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) {
      setState(() {
        _uploadedImage = file;
        _hasInitialImage = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _uploadedImage = null;
      _hasInitialImage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: EdgeInsets.all(DesignTokens.space8.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildServiceImage(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildDescription(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildServiceTypeDropdown(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildDescriptionField(),
                          SizedBox(height: DesignTokens.space6.h),
                          _buildImageUpload(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space8.w,
        DesignTokens.space6.h,
        DesignTokens.space8.w,
        DesignTokens.space4.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.backgroundColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32.sp,
              height: 32.sp,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.textSecondary,
                size: 18.sp,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'تفاصيل الخدمة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: 32.sp),
        ],
      ),
    );
  }

  Widget _buildServiceImage() {
    return Container(
      width: double.infinity,
      height: 160.h,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Image.network(
            widget.imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.backgroundColor,
              child: Center(
                child: Icon(
                  Icons.image_rounded,
                  color: AppTheme.textTertiary,
                  size: 40.sp,
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.space6.w),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4.w,
                  vertical: DesignTokens.space1.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusSm.r),
                ),
                child: Text(
                  widget.serviceName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      'إصلاح تسربات المياه - تركيب تشطبيات حمام ومطبخ وغيرها.',
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
  }

  Widget _buildServiceTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حدد نوع الخدمة',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: DesignTokens.space2.h),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor70,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.space6.w),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubService,
              isExpanded: true,
              hint: Text(
                'اختر نوع الخدمة المطلوبة...',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textSecondary,
                size: 16.sp,
              ),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
              items: _subServices.map((s) {
                return DropdownMenuItem<String>(
                  value: s['value'] as String,
                  child: Text(s['label'] as String),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedSubService = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'وصف المشكلة (اختياري)',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: DesignTokens.space2.h),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor70,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: TextField(
            controller: _descriptionController,
            textDirection: TextDirection.rtl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'مثال: يوجد تسريب أسفل الحوض في الحمام...',
              hintTextDirection: TextDirection.rtl,
              hintStyle: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11.sp,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd.r),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd.r),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd.r),
                borderSide: BorderSide(
                  color: AppTheme.primaryColor,
                ),
              ),
              contentPadding: EdgeInsets.all(DesignTokens.space6.w),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إضافة صور (اختياري)',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: DesignTokens.space2.h),
        Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 64.sp,
                height: 64.sp,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.borderColor,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusMd.r),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: AppTheme.textTertiary,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_uploadedImage != null || _hasInitialImage) ...[
              SizedBox(width: DesignTokens.space3.w),
              _buildImagePreview(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          width: 64.sp,
          height: 64.sp,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: _uploadedImage != null
              ? Image.file(
                  File(_uploadedImage!.path),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&q=80&w=150',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.backgroundColor,
                  ),
                ),
        ),
        Positioned(
          top: 2.sp,
          left: 2.sp,
          child: GestureDetector(
            onTap: _removeImage,
            child: Container(
              width: 16.sp,
              height: 16.sp,
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 9.sp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(DesignTokens.space8.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.surfaceColor70, width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingLocationTimeScreen(
                serviceId: widget.serviceId ?? '',
                serviceName: widget.serviceName,
                servicePrice: widget.price,
                serviceImage: widget.imageUrl,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: DesignTokens.space4.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd.r),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'التالي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/login_prompt.dart';
import '../../../core/widgets/map_picker_screen.dart';
import 'client_checkout_screen.dart';
import 'waiting_for_provider_screen.dart';

class BookingScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String serviceImage;
  final String servicePrice;

  const BookingScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.serviceImage,
    required this.servicePrice,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _currentStep = 0; // 0: Service, 1: Location, 2: Details, 3: Confirmation
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  String _selectedTime = 'الآن';
  String _timeOption = 'now'; // 'now', 'soon', 'later'

  // Service details
  String _problemDescription = '';
  XFile? _problemImage;

  // Location
  LatLng? _selectedLocation;
  String _addressText = '';
  bool _isAutoCapturing = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
    _autoCaptureLocation();
  }

  Future<void> _autoCaptureLocation() async {
    setState(() => _isAutoCapturing = true);
    try {
      bool serviceEnabled = await LocationService.handleLocationPermission();
      if (serviceEnabled) {
        final pos = await LocationService.getPreciseLatLng();
        if (pos != null && mounted) {
          setState(() {
            _selectedLocation = LatLng(pos.latitude, pos.longitude);
            _addressText = 'تم تحديد موقعك تلقائياً';
          });
        }
      }
    } catch (e) {
      debugPrint('Auto-capture location error: $e');
    }
    if (mounted) setState(() => _isAutoCapturing = false);
  }

  final List<String> _weekDays = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  String get _monthName {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return months[_currentMonth.month - 1];
  }

  int get _daysInMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  int get _firstDayOffset {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    int dartWeekday = firstDay.weekday;
    return dartWeekday == 7 ? 0 : dartWeekday;
  }

  Future<void> _proceedToNext() async {
    if (!SupabaseService.isLoggedIn) {
      LoginPrompt.show(context);
      return;
    }

    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تحديد موقعك'), backgroundColor: AppTheme.errorColor),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      await _createBooking();
    }
  }

  Future<void> _createBooking() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      String timeSlot;
      if (_timeOption == 'now') {
        timeSlot = 'الآن';
      } else if (_timeOption == 'soon') {
        timeSlot = 'خلال ساعتين';
      } else {
        timeSlot = _selectedDate != null
            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} $_selectedTime'
            : 'لاحقاً';
      }

      final bookingData = {
        'client_id': userId,
        'service_id': widget.serviceId,
        'status': 'pending',
        'total_price': double.tryParse(widget.servicePrice) ?? 0,
        'client_lat': _selectedLocation?.latitude,
        'client_lng': _selectedLocation?.longitude,
        'address': _addressText,
        'notes': _problemDescription,
        'scheduled_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await SupabaseService.db
          .from('bookings')
          .insert(bookingData)
          .select()
          .single();

      if (mounted) {
        if (_problemImage != null) {
          try {
            await SupabaseService.db.storage.from('booking-photos').upload(
              '${response['id']}/${_problemImage!.name}',
              File(_problemImage!.path),
            );
          } catch (e) {
            debugPrint('Error uploading image: $e');
          }
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingForProviderScreen(
              bookingId: response['id'].toString(),
              serviceName: widget.serviceName,
              totalPrice: double.tryParse(widget.servicePrice) ?? 0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.serviceName),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressStepper(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DesignTokens.space24),
                child: _buildCurrentStep(),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStepper() {
    final steps = ['الخدمة', 'الموقع', 'التفاصيل', 'التأكيد'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space24, vertical: DesignTokens.space16),
      color: Colors.white,
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isCompleted = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? AppTheme.primaryColor : Colors.grey.shade300,
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isActive = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          return GestureDetector(
            onTap: () {
              if (stepIndex <= _currentStep) {
                setState(() => _currentStep = stepIndex);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppTheme.primaryColor
                        : isActive
                            ? AppTheme.primaryColor
                            : Colors.grey.shade200,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? AppTheme.primaryColor : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomButton() {
    final labels = ['التالي', 'التالي', 'التالي', 'تأكيد الطلب'];
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _proceedToNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
          ),
          child: Text(
            labels[_currentStep],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildServiceStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildConfirmationStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildServiceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service info
        Container(
          padding: const EdgeInsets.all(DesignTokens.space8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: DesignTokens.brXl,
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: DesignTokens.brMd,
                child: Image.network(
                  widget.serviceImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.settings_rounded, color: AppTheme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: DesignTokens.space2),
                    Text('${widget.servicePrice} ج.م',
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space12),

        // Problem Description
        const Text('وصف المشكلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: DesignTokens.space4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: DesignTokens.brLg,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'اكتب وصفاً تفصيلياً للمشكلة...',
            ),
            onChanged: (v) => _problemDescription = v,
          ),
        ),
        const SizedBox(height: DesignTokens.space8),

        // Add Image (Optional)
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final img = await picker.pickImage(source: ImageSource.gallery);
            if (img != null) setState(() => _problemImage = img);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: DesignTokens.brXl,
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid, width: 1.5),
            ),
            child: Column(
              children: [
                if (_problemImage != null) ...[
                  ClipRRect(
                    borderRadius: DesignTokens.brMd,
                    child: Image.file(File(_problemImage!.path), height: 100, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  const Text('اضغط لتغيير الصورة',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ] else ...[
                  const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor, size: 40),
                  const SizedBox(height: DesignTokens.space4),
                  const Text('إضافة صورة (اختياري)', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space12),

        // Time Options
        const Text('وقت الخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: DesignTokens.space6),
        _buildTimeOption('الآن', 'now', Icons.bolt_rounded),
        const SizedBox(height: DesignTokens.space4),
        _buildTimeOption('خلال ساعتين', 'soon', Icons.schedule_rounded),
        const SizedBox(height: DesignTokens.space4),
        _buildTimeOption('حدد وقت لاحق', 'later', Icons.calendar_today_rounded),

        if (_timeOption == 'later') ...[
          const SizedBox(height: DesignTokens.space8),
          _buildCalendar(),
        ],
      ],
    );
  }

  Widget _buildTimeOption(String label, String value, IconData icon) {
    final isSelected = _timeOption == value;
    return GestureDetector(
      onTap: () => setState(() => _timeOption = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8, vertical: DesignTokens.space7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: DesignTokens.brMd,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey, size: 20),
            const SizedBox(width: DesignTokens.space6),
            Text(label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brXl,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(10, 10),
                ),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                  });
                },
                child: const Icon(Icons.chevron_left_rounded, size: 24),
              ),
              Text('$_monthName ${_currentMonth.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(10, 10),
                ),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                  });
                },
                child: const Icon(Icons.chevron_right_rounded, size: 24),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekDays
                .map((day) => SizedBox(
                      width: 36,
                      child: Text(day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
          const SizedBox(height: DesignTokens.space4),
          ...List.generate(
            (_daysInMonth + _firstDayOffset + 6) ~/ 7,
            (weekIndex) {
              final children = <Widget>[];
              for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
                final day = weekIndex * 7 + dayIndex - _firstDayOffset + 1;
                if (day < 1 || day > _daysInMonth) {
                  children.add(const SizedBox(width: 36, height: 36));
                } else {
                  final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                  final isToday = date.day == DateTime.now().day &&
                      date.month == DateTime.now().month &&
                      date.year == DateTime.now().year;
                  final isSelected = _selectedDate != null &&
                      date.day == _selectedDate!.day &&
                      date.month == _selectedDate!.month &&
                      date.year == _selectedDate!.year;
                  final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                  children.add(
                    GestureDetector(
                      onTap: isPast ? null : () => setState(() => _selectedDate = date),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : isToday
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : null,
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isPast
                                      ? Colors.grey.shade300
                                      : AppTheme.textPrimary,
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('حدد موقعك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: DesignTokens.space4),
        Text('يرجى تأكيد موقعك لوصول مقدم الخدمة إليك',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: DesignTokens.space8),

        // Auto-location status
        Container(
          padding: const EdgeInsets.all(DesignTokens.space6),
          decoration: BoxDecoration(
            color: _selectedLocation != null
                ? AppTheme.successColor.withValues(alpha: 0.1)
                : AppTheme.primaryColor.withValues(alpha: 0.05),
            borderRadius: DesignTokens.brMd,
          ),
          child: Row(
            children: [
              Icon(
                _selectedLocation != null ? Icons.check_circle_rounded : Icons.info_rounded,
                color: _selectedLocation != null ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              const SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Text(
                  _isAutoCapturing
                      ? 'جاري تحديد موقعك...'
                      : _selectedLocation != null
                          ? _addressText.isNotEmpty ? _addressText : 'تم تحديد موقعك'
                          : 'اضغط لتحديد موقعك يدوياً',
                  style: TextStyle(
                    color: _selectedLocation != null ? AppTheme.successColor : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space8),

        // Map button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: DesignTokens.brLg,
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space6),
                shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
              ),
              onPressed: () async {
                final location = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapPickerScreen(
                      initialLocation: _selectedLocation ?? const LatLng(30.0444, 31.2357),
                    ),
                  ),
                );
                if (location != null && mounted) {
                  setState(() {
                    _selectedLocation = location;
                    _addressText = 'تم تحديد الموقع يدوياً';
                  });
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: DesignTokens.space4),
                  Text('فتح الخريطة', style: TextStyle(color: AppTheme.primaryColor, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مراجعة طلبك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: DesignTokens.space8),

        _buildInfoCard(Icons.settings_rounded, 'الخدمة', widget.serviceName),
        const SizedBox(height: DesignTokens.space6),
        _buildInfoCard(Icons.attach_money_rounded, 'السعر', '${widget.servicePrice} ج.م'),
        const SizedBox(height: DesignTokens.space6),
        _buildInfoCard(
          Icons.schedule_rounded,
          'الوقت',
          _timeOption == 'now'
              ? 'الآن'
              : _timeOption == 'soon'
                  ? 'خلال ساعتين'
                  : '${_selectedDate?.day}/${_selectedDate?.month} $_selectedTime',
        ),
        const SizedBox(height: DesignTokens.space6),
        _buildInfoCard(
          Icons.location_on_rounded,
          'الموقع',
          _addressText.isNotEmpty ? _addressText : 'تم تحديد الموقع',
        ),
        const SizedBox(height: DesignTokens.space6),
        if (_problemDescription.isNotEmpty)
          _buildInfoCard(Icons.description_rounded, 'الوصف', _problemDescription),
        const SizedBox(height: DesignTokens.space6),
        if (_problemImage != null)
          _buildInfoCard(Icons.photo_rounded, 'الصورة', 'تم إرفاق صورة'),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignTokens.brMd,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(width: DesignTokens.space6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تأكيد الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: DesignTokens.space4),
        Text('يرجى مراجعة طلبك قبل التأكيد', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: DesignTokens.space8),

        _buildInfoCard(Icons.settings_rounded, 'الخدمة', widget.serviceName),
        const SizedBox(height: DesignTokens.space4),
        _buildInfoCard(Icons.attach_money_rounded, 'السعر', '${widget.servicePrice} ج.م'),
        const SizedBox(height: DesignTokens.space4),
        _buildInfoCard(
          Icons.schedule_rounded,
          'الوقت',
          _timeOption == 'now'
              ? 'الآن'
              : _timeOption == 'soon'
                  ? 'خلال ساعتين'
                  : '${_selectedDate?.day}/${_selectedDate?.month} $_selectedTime',
        ),
        const SizedBox(height: DesignTokens.space4),
        _buildInfoCard(
          Icons.location_on_rounded,
          'الموقع',
          _addressText.isNotEmpty ? _addressText : 'تم تحديد الموقع',
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

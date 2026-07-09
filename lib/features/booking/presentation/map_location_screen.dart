import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/location_service.dart';

class MapLocationScreen extends StatefulWidget {
  const MapLocationScreen({super.key});

  @override
  State<MapLocationScreen> createState() => _MapLocationScreenState();
}

class _MapLocationScreenState extends State<MapLocationScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(30.0444, 31.2357); // Default Cairo

  final List<Map<String, dynamic>> _savedLocations = [
    {'name': 'المنزل', 'icon': Icons.home_rounded, 'address': 'المعادي، شارع ٩، عمارة ١٥'},
    {'name': 'العمل', 'icon': Icons.work_rounded, 'address': 'التجمع الخامس، شارع التسعين'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToMyLocation();
    });
  }

  Future<void> _goToMyLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final point = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          _mapController.move(point, 15.0);
          setState(() => _selectedLocation = point);
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Widget _buildCustomMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background
        _PulseCircle(color: AppTheme.primaryColor),
        // Main marker icon
        Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 45),
        // Center dot
        Positioned(
          top: 12,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'أماكن محفوظة',
                          style: TextStyle(
                            fontSize: DesignTokens.textTitleSmall,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        ElevatedButton(
                          padding: EdgeInsets.zero,
                          onPressed: _goToMyLocation,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 20),
                              SizedBox(width: 4.w),
                              Text(
                                'تحديد موقعي',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: DesignTokens.textLabelMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DesignTokens.space16),
                    ..._savedLocations.map((loc) => Padding(
                      padding: EdgeInsets.only(bottom: DesignTokens.space12),
                      child: ElevatedButton(
                        padding: EdgeInsets.all(DesignTokens.space12),
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                        onPressed: () {
                          // In a real app, update _selectedLocation based on loc coordinates
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(DesignTokens.space8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                              ),
                              child: Icon(
                                loc['icon'] as IconData,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: DesignTokens.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc['name'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                      fontSize: DesignTokens.textBodyMedium,
                                    ),
                                  ),
                                  Text(
                                    loc['address'] as String,
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
                    )),
                    SizedBox(height: DesignTokens.space16),
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedLocation);
                        },
                        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                        color: AppTheme.primaryColor,
                        child: Text(
                          'تأكيد الموقع',
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
    );
  }
}

class _PulseCircle extends StatefulWidget {
  final Color color;
  const _PulseCircle({required this.color});

  @override
  State<_PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<_PulseCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 60 * _controller.value,
          height: 60 * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.4 * (1 - _controller.value)),
          ),
        );
      },
    );
  }
}

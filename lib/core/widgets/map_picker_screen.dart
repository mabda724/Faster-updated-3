import '../../core/theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/location_service.dart';
import '../services/supabase_service.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({
    super.key,
    this.initialLocation = const LatLng(30.0444, 31.2357),
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String _address = 'جاري تحديد العنوان...';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _savedAddresses = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _getAddressFromLatLng(_selectedLocation);
    _tryGetCurrentLocation();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _tryGetCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final newLoc = LatLng(pos.latitude, pos.longitude);
        setState(() => _selectedLocation = newLoc);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(newLoc, 15);
            } catch (_) {}
          }
        });
        _getAddressFromLatLng(newLoc);
      }
    } catch (e) {
      debugPrint('GPS unavailable: $e');
    }
  }

  Future<void> _loadSavedAddresses() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final data = await SupabaseService.db
          .from('addresses')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _savedAddresses = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('Load addresses error: $e');
    }
  }

  void _selectSavedAddress(Map<String, dynamic> address) {
    final lat = double.tryParse(address['lat']?.toString() ?? '');
    final lng = double.tryParse(address['lng']?.toString() ?? '');
    if (lat == null || lng == null) return;
    final loc = LatLng(lat, lng);
    setState(() {
      _selectedLocation = loc;
      _address = address['full_address'] ?? _address;
    });
    _mapController.move(loc, 16);
  }

  Future<void> _saveCurrentAddress() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    final title = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
      ),
      builder: (context) {
        String selected = 'البيت';
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.all(DesignTokens.space20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'احفظ المكان باسم',
                  style: TextStyle(fontSize: DesignTokens.textTitleMedium, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: DesignTokens.space16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'البيت',
                      label: Text('البيت'),
                      icon: Icon(Icons.home_rounded),
                    ),
                    ButtonSegment(
                      value: 'مكان تاني',
                      label: Text('مكان تاني'),
                      icon: Icon(Icons.location_on_rounded),
                    ),
                  ],
                  selected: {selected},
                  onSelectionChanged: (v) =>
                      setSheetState(() => selected = v.first),
                ),
                SizedBox(height: DesignTokens.space20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    onPressed: () => Navigator.pop(context, selected),
                    child: Text(
                      'حفظ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (title == null) return;
    try {
      await SupabaseService.db.from('addresses').insert({
        'user_id': uid,
        'title': title,
        'full_address': _address,
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
      });
      await _loadSavedAddresses();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ المكان')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('معرفتش أحفظ المكان: $e')));
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    try {
      final addr = await LocationService.getAddressFromLatLng(location);
      if (mounted) {
        setState(() {
          _address = addr;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(query);
    });
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final res = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&accept-language=ar&countrycodes=eg',
        ),
        headers: {'User-Agent': 'Faster-App/1.0'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        setState(() {
          _searchResults = data
              .map(
                (item) => {
                  'display_name': item['display_name'],
                  'lat': double.parse(item['lat']),
                  'lon': double.parse(item['lon']),
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final newLoc = LatLng(result['lat'], result['lon']);
    setState(() {
      _selectedLocation = newLoc;
      _address = result['display_name'];
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(newLoc, 16);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حدد مكانك'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location_rounded, color: AppTheme.primaryColor),
            tooltip: 'تحديد موقعي الحالي',
            onPressed: _tryGetCurrentLocation,
          ),
          IconButton(
            icon: Icon(Icons.bookmark_add_outlined, color: AppTheme.primaryColor),
            tooltip: 'احفظ المكان',
            onPressed: _saveCurrentAddress,
          ),
          IconButton(
            icon: Icon(Icons.check, color: AppTheme.primaryColor),
            tooltip: 'تأكيد',
            onPressed: () => Navigator.pop(context, {
              'location': _selectedLocation,
              'address': _address,
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                  _searchResults = [];
                });
                _getAddressFromLatLng(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.faster.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 80,
                    height: 80,
                    child: Icon(
                      Icons.location_on,
                      color: AppTheme.errorColor,
                      size: DesignTokens.iconXl,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Search bar + dropdown results
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: DesignTokens.brMd,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن عنوان أو منطقة...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                              width: DesignTokens.space20,
                              height: DesignTokens.space20,
                              child: Padding(
                                padding: EdgeInsets.all(DesignTokens.space12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: DesignTokens.iconMd),
                              tooltip: 'إغلاق',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchAddress,
                  ),
                ),

                // Search results dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: DesignTokens.space4),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: DesignTokens.brMd,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.primaryColor,
                            size: DesignTokens.iconMd,
                          ),
                          title: Text(
                            result['display_name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: DesignTokens.textBodyMedium),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Current location button
          Positioned(
            bottom: 240,
            right: 16,
              child: FloatingActionButton.small(
                heroTag: 'my_location',
                onPressed: _tryGetCurrentLocation,
                backgroundColor: AppTheme.surfaceColor,
                child: Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),

          // Address card at bottom
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: DesignTokens.brLg,
              ),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppTheme.primaryColor),
                        const SizedBox(width: DesignTokens.space8),
                        Expanded(
                          child: Text(
                            _address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: DesignTokens.textBodyMedium),
                          ),
                        ),
                      ],
                    ),
                    if (_savedAddresses.isNotEmpty) ...[
                      SizedBox(height: DesignTokens.space12),
                      SizedBox(
                        height: DesignTokens.space40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _savedAddresses.length,
                          separatorBuilder: (_, __) => SizedBox(width: DesignTokens.space8),
                          itemBuilder: (context, index) {
                            final item = _savedAddresses[index];
                            final title = item['title'] ?? 'مكان محفوظ';
                            return ActionChip(
                              avatar: Icon(
                                title == 'البيت'
                                    ? Icons.home_rounded
                                    : Icons.location_on_rounded,
                                size: DesignTokens.iconSm,
                              ),
                              label: Text(title),
                              onPressed: () => _selectSavedAddress(item),
                            );
                          },
                        ),
                      ),
                    ],
                    SizedBox(height: DesignTokens.space16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: DesignTokens.brMd,
                          ),
                          padding: EdgeInsets.symmetric(vertical: DesignTokens.space16),
                        ),
                        onPressed: () => Navigator.pop(context, {
                          'location': _selectedLocation,
                          'address': _address,
                        }),
        child: Text(
          'تأكيد الموقع',
          style: TextStyle(
            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textTitleSmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

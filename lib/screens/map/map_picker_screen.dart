import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);

// Result returned when user confirms a location
class MapPickResult {
  final LatLng latLng;
  final String address;
  MapPickResult({required this.latLng, required this.address});
}

class MapPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;

  const MapPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _ulaanbaatar = LatLng(47.9076, 106.8832);

  late final MapController _mapController;
  LatLng _center = _ulaanbaatar;
  String _address = 'Move map to select location';
  bool _resolving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = widget.initialLocation ?? _ulaanbaatar;
    if (widget.initialLocation != null) {
      _resolveAddress(_center);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng pos) async {
    setState(() => _resolving = true);
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty && mounted) {
        final m = marks.first;
        final parts = [
          if (m.street?.isNotEmpty == true) m.street,
          if (m.subLocality?.isNotEmpty == true) m.subLocality,
          if (m.locality?.isNotEmpty == true) m.locality,
        ];
        setState(() {
          _address = parts.isNotEmpty
              ? parts.join(', ')
              : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _showSnack('Location permission denied');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied — enable in settings');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      _mapController.move(ll, 16);
      setState(() => _center = ll);
      _resolveAddress(ll);
    } catch (e) {
      _showSnack('Could not get location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _confirm() {
    Navigator.pop(
      context,
      MapPickResult(latLng: _center, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final textPri = dark ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
    final textSec = dark ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
    final cardBg  = dark ? const Color(0xFF2C2C2C) : Colors.white;
    const purple  = Color(0xFF89F336);
    const orange  = Color(0xFF89F336);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
          style: TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPri),
      ),
      body: Stack(children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _center,
            zoom: 14,
            onPositionChanged: (pos, hasGesture) {
              if (hasGesture && pos.center != null) {
                setState(() => _center = pos.center!);
              }
            },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd || event is MapEventScrollWheelZoom) {
                _resolveAddress(_center);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.truckcab.app',
            ),
          ],
        ),

        // Center pin (always fixed in center)
        const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_pin, color: Color(0xFF89F336), size: 46),
            SizedBox(height: 23), // offset for pin tip
          ]),
        ),

        // My location button
        Positioned(
          right: 16,
          bottom: 160,
          child: FloatingActionButton.small(
            heroTag: 'locate',
            backgroundColor: cardBg,
            onPressed: _locating ? null : _goToMyLocation,
            child: _locating
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: purple))
                : const Icon(Icons.my_location_rounded, color: purple),
          ),
        ),

        // Bottom address card + confirm button
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.4 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Drag handle
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: textSec.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded, color: orange, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Selected location',
                    style: TextStyle(color: textSec, fontSize: 12)),
                  const SizedBox(height: 3),
                  _resolving
                      ? Row(children: [
                          SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: textSec)),
                          const SizedBox(width: 8),
                          Text('Resolving address…',
                            style: TextStyle(color: textSec, fontSize: 13)),
                        ])
                      : Text(_address,
                          style: TextStyle(
                            color: textPri, fontSize: 14,
                            fontWeight: FontWeight.w600, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _resolving ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text('Confirm Location',
                    style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

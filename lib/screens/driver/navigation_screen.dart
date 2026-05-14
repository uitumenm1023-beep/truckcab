import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order_model.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;

const _purple = Color(0xFF89F336);
const _orange = Color(0xFF89F336);
const _green  = Color(0xFF89F336);
const _blue   = Color(0xFF3B82F6);

class NavigationScreen extends StatefulWidget {
  final OrderModel order;
  /// true  → driving to pickup location
  /// false → driving to dropoff location
  final bool isPickup;

  const NavigationScreen({
    super.key,
    required this.order,
    required this.isPickup,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _posStream;

  LatLng? _driverPos;
  List<LatLng> _routePoints = [];
  double _distanceM = 0;
  int _durationS = 0;
  bool _routeLoading = false;
  bool _locating = true;
  bool _arrived = false;
  LatLng? _lastFetchPos;

  // ── Destination helpers ───────────────────────────────────────────────────
  LatLng get _dest => LatLng(
    widget.isPickup
        ? widget.order.pickupLat!
        : widget.order.dropoffLat!,
    widget.isPickup
        ? widget.order.pickupLng!
        : widget.order.dropoffLng!,
  );

  String get _destLabel =>
      widget.isPickup ? 'Pickup Location' : 'Dropoff Location';

  String get _destAddress =>
      widget.isPickup
          ? widget.order.pickupLocation
          : widget.order.dropoffLocation;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _map.dispose();
    super.dispose();
  }

  // ── Location tracking ─────────────────────────────────────────────────────
  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locating = false);
      _snack('Location services are disabled');
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        if (mounted) setState(() => _locating = false);
        _snack('Location permission denied');
        return;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locating = false);
      _snack('Location permission permanently denied');
      return;
    }

    // Initial position
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _onPosition(pos);
    } catch (_) {}

    // Continuous updates
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // update every 15 m
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position pos) {
    final ll = LatLng(pos.latitude, pos.longitude);

    setState(() {
      _driverPos = ll;
      _locating = false;
    });

    // Keep map centred on driver
    try {
      _map.move(ll, math.max(_map.camera.zoom, 15.0));
    } catch (_) {}

    // Check arrival (≤ 50 m)
    final dist = _metersTo(ll, _dest);
    setState(() {
      _distanceM = dist;
      if (dist < 50 && !_arrived) _arrived = true;
    });

    // Refresh route every 200 m of movement
    if (_lastFetchPos == null || _metersTo(ll, _lastFetchPos!) > 200) {
      _lastFetchPos = ll;
      _fetchRoute(ll);
    }
  }

  // ── OSRM route fetch ──────────────────────────────────────────────────────
  Future<void> _fetchRoute(LatLng from) async {
    setState(() => _routeLoading = true);
    try {
      final dest = _dest;
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=geojson';

      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final geom   = route['geometry'] as Map<String, dynamic>;
          final coords = geom['coordinates'] as List;
          final pts = coords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble()))
              .toList();
          final dist = (route['distance'] as num).toDouble();
          final dur  = (route['duration'] as num).toInt();
          if (mounted) {
            setState(() {
              _routePoints = pts;
              _distanceM   = dist;
              _durationS   = dur;
            });
          }
        }
      }
    } catch (_) {
      // Silently fall back to straight-line display
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _metersTo(LatLng a, LatLng b) {
    const d = Distance();
    return d(a, b).toDouble();
  }

  String _fmtDist(double m) {
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  String _fmtEta(int s) {
    if (s < 60) return '< 1 min';
    final m = (s / 60).ceil();
    if (m < 60) return '$m min';
    return '${m ~/ 60}h ${m % 60}m';
  }

  Future<void> _openExternalMaps() async {
    final dest = _dest;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${dest.latitude},${dest.longitude}'
        '&travelmode=driving');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dark    = _isDark(context);
    final textPri = dark ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
    final textSec = dark ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
    final cardBg  = dark ? const Color(0xFF2C2C2C) : Colors.white;
    final destColor = widget.isPickup ? _green : _orange;

    return Scaffold(
      body: _locating
          ? _buildLocating(dark, textPri, textSec)
          : Stack(children: [
              // ── Map ──────────────────────────────────────────────────────
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  center: _driverPos ?? _dest,
                  zoom: 15,
                  maxZoom: 18,
                  minZoom: 5,
                ),
                children: [
                  // OSM tiles
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.truckcab.app',
                  ),
                  // Route polyline
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5,
                        color: _blue.withOpacity(0.85),
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white.withOpacity(0.6),
                      ),
                    ]),
                  // Markers
                  MarkerLayer(markers: [
                    // Destination pin
                    Marker(
                      point: _dest,
                      width: 48,
                      height: 58,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: destColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: destColor.withOpacity(0.5),
                                  blurRadius: 8),
                              ],
                            ),
                            child: Icon(
                              widget.isPickup
                                  ? Icons.inventory_2_rounded
                                  : Icons.flag_rounded,
                              color: Colors.white, size: 16),
                          ),
                          Container(width: 2, height: 8,
                            color: destColor),
                        ],
                      ),
                    ),
                    // Driver position arrow
                    if (_driverPos != null)
                      Marker(
                        point: _driverPos!,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: _blue.withOpacity(0.4),
                                blurRadius: 12, spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.navigation_rounded,
                            color: Colors.white, size: 22),
                        ),
                      ),
                  ]),
                ],
              ),

              // ── Top info bar ─────────────────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                child: _TopBar(
                  dark: dark, cardBg: cardBg,
                  textPri: textPri, textSec: textSec,
                  destLabel: _destLabel,
                  destAddress: _destAddress,
                  destColor: destColor,
                  distText: _driverPos != null ? _fmtDist(_distanceM) : '…',
                  etaText: _durationS > 0 ? _fmtEta(_durationS) : '…',
                  routeLoading: _routeLoading,
                  onClose: () => Navigator.pop(context),
                ),
              ),

              // ── Arrived banner ────────────────────────────────────────────
              if (_arrived)
                Positioned(
                  left: 16, right: 16,
                  bottom: 140 + MediaQuery.of(context).padding.bottom,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withOpacity(0.4),
                          blurRadius: 20, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('You have arrived!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(widget.isPickup
                              ? 'Pick up the package now'
                              : 'Deliver the package',
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                        ],
                      )),
                    ]),
                  ),
                ),

              // ── Bottom action bar ─────────────────────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _BottomBar(
                  dark: dark, cardBg: cardBg,
                  textSec: textSec,
                  onRecenter: () {
                    if (_driverPos != null) {
                      _map.move(_driverPos!, 15);
                    }
                  },
                  onExternalMaps: _openExternalMaps,
                ),
              ),
            ]),
    );
  }

  Widget _buildLocating(bool dark, Color textPri, Color textSec) {
    final cardBg = dark ? const Color(0xFF2C2C2C) : Colors.white;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5),
      appBar: AppBar(
        title: Text(_destLabel,
          style: TextStyle(color: textPri, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPri),
      ),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.1), shape: BoxShape.circle),
          child: const Center(
            child: CircularProgressIndicator(color: _blue, strokeWidth: 3))),
        const SizedBox(height: 20),
        Text('Getting your location…',
          style: TextStyle(
            color: textPri, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Please allow location access',
          style: TextStyle(color: textSec, fontSize: 13)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(widget.isPickup
                ? Icons.inventory_2_outlined : Icons.flag_outlined,
              color: widget.isPickup ? _green : _orange, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(_destAddress,
              style: TextStyle(
                color: textPri, fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ])),
    );
  }
}

// ── Top bar widget ────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool dark, routeLoading;
  final Color cardBg, textPri, textSec, destColor;
  final String destLabel, destAddress, distText, etaText;
  final VoidCallback onClose;

  const _TopBar({
    required this.dark, required this.cardBg,
    required this.textPri, required this.textSec,
    required this.destLabel, required this.destAddress,
    required this.destColor, required this.distText,
    required this.etaText, required this.routeLoading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.4 : 0.12),
            blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // Close + destination
        Row(children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFF7FA3A7),
                shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_rounded,
                color: textPri, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: destColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(destLabel,
                  style: TextStyle(
                    color: destColor, fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
              ]),
              const SizedBox(height: 2),
              Text(destAddress,
                style: TextStyle(
                  color: textPri, fontSize: 15,
                  fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
        const SizedBox(height: 12),
        // Distance / ETA row
        routeLoading
            ? LinearProgressIndicator(
                color: const Color(0xFF3B82F6),
                backgroundColor:
                    dark ? const Color(0xFF3A3A3A) : const Color(0xFF5E8A8F),
                minHeight: 3)
            : Row(children: [
                _Pill(Icons.straighten_rounded, distText,
                  const Color(0xFF3B82F6), dark),
                const SizedBox(width: 10),
                _Pill(Icons.timer_outlined, etaText,
                  const Color(0xFF89F336), dark),
              ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool dark;
  const _Pill(this.icon, this.text, this.color, this.dark);

  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 5),
      Text(text,
        style: TextStyle(
          color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    ]),
  );
}

// ── Bottom bar widget ─────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool dark;
  final Color cardBg, textSec;
  final VoidCallback onRecenter, onExternalMaps;

  const _BottomBar({
    required this.dark, required this.cardBg,
    required this.textSec,
    required this.onRecenter, required this.onExternalMaps,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.4 : 0.1),
            blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        // Recenter button
        GestureDetector(
          onTap: onRecenter,
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: dark
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFF7FA3A7),
              borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.my_location_rounded,
              color: Color(0xFF3B82F6), size: 24)),
        ),
        const SizedBox(width: 12),
        // Open in Google Maps
        Expanded(child: GestureDetector(
          onTap: onExternalMaps,
          child: Container(
            height: 52, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFF7FA3A7),
              borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded,
                  color: textSec, size: 16),
                const SizedBox(width: 8),
                Text('Open in Google Maps',
                  style: TextStyle(
                    color: textSec, fontWeight: FontWeight.w600,
                    fontSize: 13)),
              ]),
          ),
        )),
      ]),
    );
  }
}

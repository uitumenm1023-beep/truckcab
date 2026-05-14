import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../map/map_picker_screen.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A1A2E);
Color _textSec(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF6B7280);
Color _card(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF1B1F26) : Colors.white;
Color _soft(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF252A33) : const Color(0xFFF0F1F8);
Color _border(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB);

const _purple = Color(0xFF7B6CF6);
const _orange = Color(0xFFFF5A1F);
const _green  = Color(0xFF22C55E);

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();

  // Location data from map picker
  String _pickupAddress  = '';
  double? _pickupLat, _pickupLng;
  String _dropoffAddress = '';
  double? _dropoffLat, _dropoffLng;

  // Photos
  final List<XFile> _photos = [];
  bool _uploadingPhotos = false;
  bool _submitting = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── Map picker ─────────────────────────────────────────────────────────────
  Future<void> _pickLocation(bool isPickup) async {
    final initial = isPickup
        ? (_pickupLat != null ? LatLng(_pickupLat!, _pickupLng!) : null)
        : (_dropoffLat != null ? LatLng(_dropoffLat!, _dropoffLng!) : null);

    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: isPickup ? 'Select Pickup Location' : 'Select Dropoff Location',
          initialLocation: initial,
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      if (isPickup) {
        _pickupAddress = result.address;
        _pickupLat     = result.latLng.latitude;
        _pickupLng     = result.latLng.longitude;
      } else {
        _dropoffAddress = result.address;
        _dropoffLat     = result.latLng.latitude;
        _dropoffLng     = result.latLng.longitude;
      }
    });
  }

  // ── Photo picker ───────────────────────────────────────────────────────────
  Future<void> _addPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, imageQuality: 75, maxWidth: 1200);
      if (file != null) setState(() => _photos.add(file));
    } catch (_) {
      _snack('Could not access camera/gallery');
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _textSec(context).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _OptionTile(
            icon: Icons.camera_alt_rounded,
            label: 'Take a photo',
            onTap: () { Navigator.pop(context); _addPhoto(ImageSource.camera); }),
          _OptionTile(
            icon: Icons.photo_library_rounded,
            label: 'Choose from gallery',
            onTap: () { Navigator.pop(context); _addPhoto(ImageSource.gallery); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Upload photos to ImgBB (free, no Firebase Storage needed) ────────────
  // 1. Sign up free at imgbb.com
  // 2. Get your API key at api.imgbb.com
  // 3. Paste it below
  static const _imgbbApiKey = '35b1056c3dd1a26c0ef5cea7e7d266cc';

  Future<List<String>> _uploadPhotos(String orderId) async {
    final urls = <String>[];
    for (final photo in _photos) {
      final bytes  = await photo.readAsBytes();
      final base64 = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
        body: {'image': base64},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final url  = json['data']['url'] as String;
        urls.add(url);
      } else {
        throw Exception('ImgBB upload failed: ${response.statusCode}');
      }
    }
    return urls;
  }

  // ── Create order ───────────────────────────────────────────────────────────
  Future<void> _createOrder() async {
    if (_submitting) return;

    if (_pickupAddress.isEmpty) {
      _snack('Please select a pickup location on the map');
      return;
    }
    if (_dropoffAddress.isEmpty) {
      _snack('Please select a dropoff location on the map');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _submitting = true; _uploadingPhotos = _photos.isNotEmpty; });

    final authProvider  = context.read<AppAuthProvider>();
    final orderProvider = context.read<OrderProvider>();
    final sellerId      = authProvider.currentUserId ?? '';
    final sellerName    = authProvider.currentUserProfile?.displayName ?? '';

    // Upload photos first if any
    List<String> imageUrls = [];
    if (_photos.isNotEmpty) {
      try {
        // Use a temp doc ID for storage path
        final tempId = FirebaseFirestore.instance.collection('orders').doc().id;
        imageUrls = await _uploadPhotos(tempId);
      } catch (_) {
        setState(() { _submitting = false; _uploadingPhotos = false; });
        _snack('Failed to upload photos. Try again.');
        return;
      }
      setState(() => _uploadingPhotos = false);
    }

    final success = await orderProvider.createOrder(
      sellerId:        sellerId,
      sellerName:      sellerName,
      pickupLocation:  _pickupAddress,
      dropoffLocation: _dropoffAddress,
      description:     _descCtrl.text.trim(),
      price:           double.parse(_priceCtrl.text.trim()),
      pickupLat:       _pickupLat,
      pickupLng:       _pickupLng,
      dropoffLat:      _dropoffLat,
      dropoffLng:      _dropoffLng,
      imageUrls:       imageUrls,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created successfully')));
      Navigator.pop(context);
    } else {
      _snack(orderProvider.errorMessage ?? 'Failed to create order');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101216) : const Color(0xFFF2F3F8),
      appBar: AppBar(
        title: Text('New Delivery Order',
          style: TextStyle(
            color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textPri(context)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 8, 20, 20 + MediaQuery.of(context).padding.bottom),
          children: [
            // ── Pickup location ──────────────────────────────────────────
            _SectionLabel('Pickup Location', context),
            _LocationTile(
              address:   _pickupAddress,
              icon:      Icons.my_location_rounded,
              color:     _green,
              hint:      'Tap to select on map',
              onTap:     () => _pickLocation(true),
              context:   context,
            ),
            const SizedBox(height: 16),

            // ── Dropoff location ─────────────────────────────────────────
            _SectionLabel('Dropoff Location', context),
            _LocationTile(
              address:   _dropoffAddress,
              icon:      Icons.flag_rounded,
              color:     _orange,
              hint:      'Tap to select on map',
              onTap:     () => _pickLocation(false),
              context:   context,
            ),
            const SizedBox(height: 16),

            // ── Package description ──────────────────────────────────────
            _SectionLabel('Package Description', context),
            _StyledField(
              ctrl:      _descCtrl,
              hint:      'e.g. 5 boxes of electronics',
              icon:      Icons.inventory_2_outlined,
              maxLines:  3,
              validator: (v) => Validators.validateText(v, 'Description'),
              context:   context,
            ),
            const SizedBox(height: 16),

            // ── Price ────────────────────────────────────────────────────
            _SectionLabel('Delivery Price (₮)', context),
            _StyledField(
              ctrl:         _priceCtrl,
              hint:         'e.g. 15000',
              icon:         Icons.payments_outlined,
              keyboardType: TextInputType.number,
              validator:    Validators.validatePrice,
              context:      context,
            ),
            const SizedBox(height: 20),

            // ── Photos ───────────────────────────────────────────────────
            _SectionLabel('Package Photos (optional)', context),
            _PhotoSection(
              photos:         _photos,
              onAdd:          _showPhotoOptions,
              onRemove:       _removePhoto,
              context:        context,
            ),
            const SizedBox(height: 28),

            // ── Submit ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _createOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _orange.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: _submitting
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(
                          _uploadingPhotos
                              ? 'Uploading photos…'
                              : 'Creating order…',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                      ])
                    : const Text('Create Order',
                        style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

Widget _SectionLabel(String text, BuildContext ctx) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text,
    style: TextStyle(
      color: _textSec(ctx),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5)),
);

class _LocationTile extends StatelessWidget {
  final String address, hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final BuildContext context;
  const _LocationTile({
    required this.address, required this.hint,
    required this.icon, required this.color,
    required this.onTap, required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final hasAddr = address.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasAddr ? color.withOpacity(0.08) : _soft(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasAddr ? color.withOpacity(0.35) : _border(context),
            width: hasAddr ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: hasAddr
              ? Text(address,
                  style: TextStyle(
                    color: _textPri(context),
                    fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis)
              : Text(hint,
                  style: TextStyle(color: _textSec(context), fontSize: 14))),
          Icon(Icons.chevron_right_rounded,
            color: hasAddr ? color : _textSec(context), size: 20),
        ]),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final BuildContext context;
  const _StyledField({
    required this.ctrl, required this.hint,
    required this.icon, this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator, required this.context,
  });

  @override
  Widget build(BuildContext ctx) => TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    validator: validator,
    style: TextStyle(color: _textPri(context), fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _textSec(context)),
      prefixIcon: Icon(icon, color: _textSec(context), size: 20),
      filled: true,
      fillColor: _soft(context),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: _border(context))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _purple, width: 1.5)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    ),
  );
}

class _PhotoSection extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final BuildContext context;
  const _PhotoSection({
    required this.photos, required this.onAdd,
    required this.onRemove, required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == photos.length) {
            // Add button
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: _soft(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _border(context), style: BorderStyle.solid)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_outlined,
                    color: _textSec(context), size: 28),
                  const SizedBox(height: 4),
                  Text('Add photo',
                    style: TextStyle(color: _textSec(context), fontSize: 11)),
                ]),
              ),
            );
          }
          // Photo thumbnail
          return Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(photos[i].path),
                width: 100, height: 100, fit: BoxFit.cover)),
            Positioned(top: 4, right: 4,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14)),
              )),
          ]);
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext ctx) => ListTile(
    leading: Icon(icon, color: _textPri(ctx)),
    title: Text(label,
      style: TextStyle(
        color: _textPri(ctx), fontWeight: FontWeight.w600)),
    onTap: onTap,
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);

const Color _purple = Color(0xFF89F336);
const Color _orange = Color(0xFF89F336);

class _VehicleData {
  final String id, label, emoji, description;
  const _VehicleData(this.id, this.label, this.emoji, this.description);
}

const _vehicles = [
  _VehicleData('suv',          'SUV',          '🚙', 'Small loads\nUp to 500kg'),
  _VehicleData('small_truck',  'Small Truck',  '🚚', 'Light deliveries\nUp to 1.5 ton'),
  _VehicleData('medium_truck', 'Medium Truck', '🚛', 'Mid freight\nUp to 5 ton'),
  _VehicleData('big_truck',    'Big Truck',    '🚜', 'Heavy hauls\nUp to 20 ton'),
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  String    _role        = AppRoles.seller;
  bool      _obscurePass = true;
  bool      _submitting  = false;
  DateTime? _birthdate;

  // Driver-only
  String? _vehicle;
  int     _yearsExp    = 1;
  bool?   _hasCrash;
  int     _crashCount  = 0;

  int _step = 0; // 0=role, 1=vehicle(driver), 2=experience(driver), 3=info

  late final AnimationController _ac;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); _phoneCtrl.dispose();
    _ac.dispose();
    super.dispose();
  }

  int get _totalSteps => _role == AppRoles.driver ? 4 : 2;

  void _goStep(int s) { _ac.forward(from: 0); setState(() => _step = s); }

  void _next() {
    if (_step == 0) {
      // Role selection — move to appropriate next step
      if (_role == AppRoles.driver) { _goStep(1); } else { _goStep(3); }
      return;
    }
    if (_step == 1) { // Vehicle selection
      if (_vehicle == null) { _snack('Please select your vehicle type'); return; }
      _goStep(2); return;
    }
    if (_step == 2) { // Experience
      _goStep(3); return;
    }
    if (_step == 3) { _submit(); }
  }

  void _back() {
    if (_step == 0) { Navigator.pushReplacementNamed(context, AppRoutes.login); return; }
    if (_step == 1) { _goStep(0); return; }
    if (_step == 2) { _goStep(1); return; }
    if (_step == 3 && _role == AppRoles.driver) { _goStep(2); return; }
    _goStep(0);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_birthdate == null) { _snack('Please select your date of birth'); return; }
    if (!_formKey.currentState!.validate()) return;
    if (_role == AppRoles.driver && (_vehicle == null || _vehicle!.isEmpty)) {
      _snack('Please select your vehicle type'); return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AppAuthProvider>();
    final ok = await auth.signUp(
      email: _emailCtrl.text.trim(), password: _passCtrl.text.trim(),
      role: _role, name: _nameCtrl.text.trim(), birthdate: _birthdate!,
      vehicleType: _vehicle ?? '', yearsExperience: _yearsExp,
      hasCrash: _hasCrash ?? false, crashCount: _crashCount,
      phoneNumber: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      _role == AppRoles.seller
          ? Navigator.pushReplacementNamed(context, AppRoutes.sellerHome)
          : Navigator.pushReplacementNamed(context, AppRoutes.driverHome);
    } else {
      final msg = auth.errorMessage ?? '';
      if (msg.contains('verify') || msg.contains('email')) {
        _showVerifyDialog(msg);
      } else {
        _snack(msg.isEmpty ? 'Signup failed' : msg);
      }
    }
  }

  void _showVerifyDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_unread_outlined, color: _purple, size: 28)),
          const SizedBox(height: 14),
          Text('Verify Your Email', style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: Text(msg, style: TextStyle(color: _textSec(context), fontSize: 14, height: 1.5), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pushReplacementNamed(context, AppRoutes.login); },
            child: const Text('Go to Login', style: TextStyle(color: _purple, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: _back,
                child: Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _border(context))),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: _textPri(context), size: 16)),
              ),
              const Spacer(),
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: _orange, shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20)),
            ]),
          ),
          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: List.generate(_totalSteps, (i) => Expanded(child: Container(
                height: 4, margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i <= _step ? _purple : _soft(context),
                  borderRadius: BorderRadius.circular(2)),
              )))),
              const SizedBox(height: 10),
              Text('Step ${_step + 1} of $_totalSteps', style: TextStyle(color: _textSec(context), fontSize: 12)),
            ]),
          ),
          // Body
          Expanded(child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(context, dark),
            ),
          )),
          // Next button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
              onTap: _submitting ? null : _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  color: _submitting ? _purple.withOpacity(0.5) : _purple,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _submitting ? [] : [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Center(child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_step == _totalSteps - 1 ? 'Create Account' : 'Continue',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStep(BuildContext context, bool dark) {
    switch (_step) {
      case 0: return _StepRole(selected: _role, onSelect: (r) => setState(() => _role = r), context: context);
      case 1: return _StepVehicle(selected: _vehicle, onSelect: (v) => setState(() => _vehicle = v), context: context);
      case 2: return _StepExperience(
        years: _yearsExp, hasCrash: _hasCrash, crashCount: _crashCount,
        onYears: (v) => setState(() => _yearsExp = v),
        onCrash: (v) => setState(() => _hasCrash = v),
        onCrashCount: (v) => setState(() => _crashCount = v),
        context: context);
      case 3: return _StepInfo(
        nameCtrl: _nameCtrl, emailCtrl: _emailCtrl, passCtrl: _passCtrl,
        phoneCtrl: _phoneCtrl, role: _role,
        formKey: _formKey, obscurePass: _obscurePass, birthdate: _birthdate,
        onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
        onBirthdate: (d) => setState(() => _birthdate = d),
        context: context);
      default: return const SizedBox.shrink();
    }
  }
}

// ── Step 0: Role ──────────────────────────────────────────────────────────────
class _StepRole extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  final BuildContext context;
  const _StepRole({required this.selected, required this.onSelect, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Join TruckCab', style: TextStyle(color: _textPri(context), fontSize: 32, fontWeight: FontWeight.w700, height: 1.2)),
      const SizedBox(height: 8),
      Text('Are you a seller or a driver?', style: TextStyle(color: _textSec(context), fontSize: 15)),
      const SizedBox(height: 36),
      _RoleCard(
        title: 'Seller', subtitle: 'I have packages to deliver', emoji: '📦',
        selected: selected == AppRoles.seller, onTap: () => onSelect(AppRoles.seller), context: context),
      const SizedBox(height: 14),
      _RoleCard(
        title: 'Driver', subtitle: 'I want to deliver packages', emoji: '🚛',
        selected: selected == AppRoles.driver, onTap: () => onSelect(AppRoles.driver), context: context),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Already have an account? ', style: TextStyle(color: _textSec(context), fontSize: 13)),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(ctx, AppRoutes.login),
          child: const Text('Login', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    ]);
  }
}

class _RoleCard extends StatelessWidget {
  final String title, subtitle, emoji;
  final bool selected;
  final VoidCallback onTap;
  final BuildContext context;
  const _RoleCard({required this.title, required this.subtitle, required this.emoji,
    required this.selected, required this.onTap, required this.context});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? _purple.withOpacity(0.1) : _card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selected ? _purple : _border(context), width: selected ? 2 : 1)),
      child: Row(children: [
        Container(width: 58, height: 58,
          decoration: BoxDecoration(color: selected ? _purple.withOpacity(0.15) : _soft(context), borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: selected ? _purple : _textPri(context), fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: _textSec(context), fontSize: 13)),
        ])),
        if (selected) const Icon(Icons.check_circle_rounded, color: _purple, size: 24),
      ]),
    ),
  );
}

// ── Step 1: Vehicle ───────────────────────────────────────────────────────────
class _StepVehicle extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;
  final BuildContext context;
  const _StepVehicle({required this.selected, required this.onSelect, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your Vehicle', style: TextStyle(color: _textPri(context), fontSize: 32, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('What type of vehicle do you drive?', style: TextStyle(color: _textSec(context), fontSize: 15)),
      const SizedBox(height: 28),
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14,
        childAspectRatio: 0.85,
        children: _vehicles.map((v) {
          final sel = selected == v.id;
          return GestureDetector(
            onTap: () => onSelect(v.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: sel ? _purple.withOpacity(0.1) : _card(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: sel ? _purple : _border(context), width: sel ? 2 : 1)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(v.emoji, style: const TextStyle(fontSize: 42)),
                  if (sel) const Icon(Icons.check_circle_rounded, color: _purple, size: 20),
                ]),
                const Spacer(),
                Text(v.label, style: TextStyle(color: sel ? _purple : _textPri(context), fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(v.description, style: TextStyle(color: _textSec(context), fontSize: 11, height: 1.4)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

// ── Step 2: Experience ────────────────────────────────────────────────────────
class _StepExperience extends StatelessWidget {
  final int years, crashCount;
  final bool? hasCrash;
  final void Function(int) onYears, onCrashCount;
  final void Function(bool?) onCrash;
  final BuildContext context;
  const _StepExperience({
    required this.years, required this.hasCrash, required this.crashCount,
    required this.onYears, required this.onCrash, required this.onCrashCount,
    required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Experience', style: TextStyle(color: _textPri(context), fontSize: 32, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Tell us about your driving history (you can skip)', style: TextStyle(color: _textSec(context), fontSize: 15)),
      const SizedBox(height: 32),
      // Years slider
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: _border(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🕐', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('Years of Experience', style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text('$years yr${years != 1 ? 's' : ''}', style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 14))),
          ]),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _purple, thumbColor: _purple,
              inactiveTrackColor: _purple.withOpacity(0.15),
              overlayColor: _purple.withOpacity(0.12)),
            child: Slider(
              value: years.toDouble(), min: 0, max: 30, divisions: 30,
              onChanged: (v) => onYears(v.round())),
          ),
        ])),
      const SizedBox(height: 14),
      // Accident question
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: _border(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('⚠️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text('Any prior accidents?', style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _YesNo('Yes', hasCrash == true, () => onCrash(true), context)),
            const SizedBox(width: 10),
            Expanded(child: _YesNo('No', hasCrash == false, () => onCrash(false), context)),
            const SizedBox(width: 10),
            Expanded(child: _YesNo('Skip', hasCrash == null, () => onCrash(null), context)),
          ]),
          if (hasCrash == true) ...[
            const SizedBox(height: 14),
            Text('How many accidents?', style: TextStyle(color: _textSec(context), fontSize: 13)),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _orange, thumbColor: _orange,
                inactiveTrackColor: _orange.withOpacity(0.15),
                overlayColor: _orange.withOpacity(0.12)),
              child: Slider(
                value: crashCount.toDouble(), min: 0, max: 10, divisions: 10,
                label: '$crashCount',
                onChanged: (v) => onCrashCount(v.round())),
            ),
            Center(child: Text('$crashCount accident${crashCount != 1 ? 's' : ''}',
              style: TextStyle(color: _orange, fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ])),
    ]);
  }
}

class _YesNo extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  final BuildContext context;
  const _YesNo(this.label, this.sel, this.onTap, this.context);

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sel ? _purple.withOpacity(0.12) : _soft(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? _purple : _border(context))),
      child: Text(label, style: TextStyle(color: sel ? _purple : _textSec(context), fontWeight: FontWeight.w700, fontSize: 13))),
  );
}

// ── Step 3: Basic Info ────────────────────────────────────────────────────────
class _StepInfo extends StatelessWidget {
  final TextEditingController nameCtrl, emailCtrl, passCtrl, phoneCtrl;
  final String role;
  final GlobalKey<FormState> formKey;
  final bool obscurePass;
  final DateTime? birthdate;
  final VoidCallback onTogglePass;
  final void Function(DateTime) onBirthdate;
  final BuildContext context;
  const _StepInfo({
    required this.nameCtrl, required this.emailCtrl, required this.passCtrl,
    required this.phoneCtrl, required this.role,
    required this.formKey, required this.obscurePass, required this.birthdate,
    required this.onTogglePass, required this.onBirthdate, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Form(
      key: formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your Details', style: TextStyle(color: _textPri(context), fontSize: 32, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Almost there! Fill in your basic info.', style: TextStyle(color: _textSec(context), fontSize: 15)),
        const SizedBox(height: 28),
        _Field(ctrl: nameCtrl, label: 'Full Name', hint: 'John Doe', icon: Icons.person_outline_rounded,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null, context: context),
        const SizedBox(height: 14),
        // Date of birth picker
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime(2000),
              firstDate: DateTime(1930),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.fromSeed(seedColor: _purple, brightness: Theme.of(ctx).brightness)),
                child: child!),
            );
            if (picked != null) onBirthdate(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _soft(context), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: birthdate == null ? _border(context) : _purple)),
            child: Row(children: [
              Icon(Icons.cake_outlined, color: birthdate == null ? _textSec(context) : _purple, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                birthdate == null ? 'Date of Birth' :
                  '${birthdate!.day}/${birthdate!.month}/${birthdate!.year}',
                style: TextStyle(color: birthdate == null ? _textSec(context) : _textPri(context), fontSize: 15))),
              Icon(Icons.calendar_today_outlined, color: _textSec(context), size: 16),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        _Field(ctrl: emailCtrl, label: 'Email', hint: 'you@example.com', icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress, validator: Validators.validateEmail, context: context),
        const SizedBox(height: 14),
        _Field(ctrl: passCtrl, label: 'Password', hint: 'Minimum 6 characters', icon: Icons.lock_outline_rounded,
          obscure: obscurePass, validator: Validators.validatePassword, context: context,
          suffix: GestureDetector(
            onTap: onTogglePass,
            child: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _textSec(context), size: 20))),
        if (role == AppRoles.seller) ...[
          const SizedBox(height: 14),
          _Field(ctrl: phoneCtrl, label: 'Phone Number', hint: '+976 9900 0000', icon: Icons.phone_outlined,
            keyboard: TextInputType.phone, context: context,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone number is required for sellers';
              return null;
            }),
        ],
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _purple.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _purple.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: _purple, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('A verification email will be sent. The app will log you in automatically once verified.',
              style: TextStyle(color: _textSec(context), fontSize: 12, height: 1.4))),
          ])),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboard;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final BuildContext context;
  const _Field({
    required this.ctrl, required this.label, required this.hint,
    required this.icon, this.obscure = false,
    this.keyboard = TextInputType.text, this.validator, this.suffix,
    required this.context});

  @override
  Widget build(BuildContext ctx) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      style: TextStyle(color: _textPri(context), fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: _textSec(context)),
        hintStyle: TextStyle(color: _textSec(context).withOpacity(0.6)),
        prefixIcon: Icon(icon, color: _textSec(context), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _soft(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _border(context))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      ),
    );
  }
}
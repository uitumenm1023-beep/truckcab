import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../routes/app_routes.dart';

// ── UPDATE THESE with your real bank account details ─────────────────────────
const _bankName    = 'Хаан Банк'; // e.g. Khan Bank
const _accountNo   = '5000123456';
const _accountName = 'TruckCab LLC';
// ─────────────────────────────────────────────────────────────────────────────

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _refCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AppAuthProvider>().currentUserId;
      if (uid != null) {
        context.read<PaymentProvider>().startUserPaymentsListener(uid);
      }
    });
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    context.read<PaymentProvider>().stopUserPaymentsListener();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AppAuthProvider>();
    final provider = context.read<PaymentProvider>();
    final ok = await provider.submitPayment(
      userId:    auth.currentUserId ?? '',
      userName:  auth.currentUserProfile?.displayName ?? '',
      userEmail: auth.currentUserEmail ?? '',
      bankRef:   _refCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _submitted = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Failed to submit')));
    }
  }

  Future<void> _logout() async {
    await context.read<AppAuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final dark     = _isDark(context);
    final textPri  = dark ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
    final textSec  = dark ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
    final card     = dark ? const Color(0xFF2C2C2C) : Colors.white;
    final soft     = dark ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
    final border   = dark ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);
    const purple   = Color(0xFF89F336);
    const orange   = Color(0xFF89F336);
    const green    = Color(0xFF89F336);

    final payments = context.watch<PaymentProvider>().userPayments;
    final hasPending = payments.any((p) => p.status == 'pending');

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 24, 20, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF89F336), Color(0xFF5B4CD6)]),
                  shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_rounded,
                  color: Colors.white, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TruckCab',
                  style: TextStyle(
                    color: textPri, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Monthly Subscription',
                  style: TextStyle(color: textSec, fontSize: 12)),
              ])),
              TextButton(
                onPressed: _logout,
                child: Text('Logout',
                  style: TextStyle(color: textSec, fontSize: 13))),
            ]),
            const SizedBox(height: 32),

            // ── Price card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF89F336), Color(0xFF5B4CD6)]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: purple.withOpacity(0.35),
                    blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(children: [
                const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white70, size: 40),
                const SizedBox(height: 12),
                const Text('₮9,900 / month',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Full access to TruckCab for 30 days',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 20),
                // Features
                ...[
                  'Post & manage delivery orders',
                  'Real-time driver tracking',
                  'In-app chat with drivers',
                  'Notification alerts',
                ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                      color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(f, style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 24),

            if (_submitted || hasPending) ...[
              // ── Pending confirmation ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: green.withOpacity(0.35))),
                child: Column(children: [
                  const Icon(Icons.hourglass_top_rounded,
                    color: green, size: 40),
                  const SizedBox(height: 12),
                  Text('Payment submitted!',
                    style: TextStyle(
                      color: textPri, fontSize: 18,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Your payment is pending admin review.\n'
                    'You will get access within 24 hours once approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSec, fontSize: 13, height: 1.5)),
                ]),
              ),
            ] else ...[
              // ── Bank details ──────────────────────────────────────────
              Text('How to pay', style: TextStyle(
                color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border)),
                child: Column(children: [
                  _BankRow('Bank',        _bankName,    textPri, textSec),
                  const SizedBox(height: 10),
                  _BankRow('Account No.',  _accountNo,  textPri, textSec,
                    copyable: true),
                  const SizedBox(height: 10),
                  _BankRow('Account Name', _accountName, textPri, textSec),
                  const SizedBox(height: 10),
                  _BankRow('Amount',       '₮9,900',    textPri, textSec,
                    valueColor: orange),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Reference form ────────────────────────────────────────
              Text('Submit payment proof', style: TextStyle(
                color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'After transferring, enter your transaction reference number below.',
                style: TextStyle(color: textSec, fontSize: 13, height: 1.45)),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _refCtrl,
                  style: TextStyle(color: textPri),
                  decoration: InputDecoration(
                    hintText: 'Transaction reference / note',
                    hintStyle: TextStyle(color: textSec),
                    prefixIcon: Icon(Icons.receipt_outlined,
                      color: textSec, size: 20),
                    filled: true, fillColor: soft,
                    contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: purple, width: 1.5)),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your transaction reference';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              Builder(builder: (ctx) {
                final loading =
                    ctx.watch<PaymentProvider>().isLoading;
                return SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                        : const Text('I\'ve Paid — Submit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                );
              }),
            ],

            // ── Past payments ─────────────────────────────────────────────
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Payment History', style: TextStyle(
                color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...payments.map((p) {
                final c = p.status == 'approved' ? green
                    : p.status == 'rejected' ? Colors.redAccent
                    : orange;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border)),
                  child: Row(children: [
                    Icon(
                      p.status == 'approved'
                          ? Icons.check_circle_rounded
                          : p.status == 'rejected'
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded,
                      color: c, size: 24),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ref: ${p.bankRef}',
                        style: TextStyle(
                          color: textPri,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(p.status.toUpperCase(),
                        style: TextStyle(
                          color: c, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                      if (p.status == 'rejected' &&
                          p.note?.isNotEmpty == true)
                        Text('Note: ${p.note}',
                          style: TextStyle(
                            color: Colors.redAccent, fontSize: 11)),
                    ])),
                    Text('₮${p.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: textSec, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  final String label, value;
  final Color textPri, textSec;
  final bool copyable;
  final Color? valueColor;
  const _BankRow(this.label, this.value, this.textPri, this.textSec,
      {this.copyable = false, this.valueColor});

  @override
  Widget build(BuildContext ctx) => Row(children: [
    Expanded(child: Text(label,
      style: TextStyle(color: textSec, fontSize: 13))),
    GestureDetector(
      onTap: copyable ? () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')));
      } : null,
      child: Row(children: [
        Text(value, style: TextStyle(
          color: valueColor ?? textPri,
          fontWeight: FontWeight.w700, fontSize: 14)),
        if (copyable) ...[
          const SizedBox(width: 6),
          const Icon(Icons.copy_rounded,
            color: Color(0xFF89F336), size: 14),
        ],
      ]),
    ),
  ]);
}

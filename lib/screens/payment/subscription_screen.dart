import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../routes/app_routes.dart';

// ── UPDATE THESE with your real bank account details ─────────────────────────
const _bankName    = 'Хаан Банк';
const _accountNo   = '5000123456';
const _accountName = 'TruckCab LLC';
// ─────────────────────────────────────────────────────────────────────────────

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;

/// Generates a 6-character ID: 3 uppercase letters + 3 digits, shuffled.
/// e.g. "A3K7B2", "X9R2M4"
String _generatePaymentId() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits  = '23456789';
  final rand = Random();
  final chars = <String>[
    ...List.generate(3, (_) => letters[rand.nextInt(letters.length)]),
    ...List.generate(3, (_) => digits[rand.nextInt(digits.length)]),
  ]..shuffle(rand);
  return chars.join();
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final String _paymentId;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _paymentId = _generatePaymentId();
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
    context.read<PaymentProvider>().stopUserPaymentsListener();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth     = context.read<AppAuthProvider>();
    final provider = context.read<PaymentProvider>();
    final ok = await provider.submitPayment(
      userId:    auth.currentUserId ?? '',
      userName:  auth.currentUserProfile?.displayName ?? '',
      userEmail: auth.currentUserEmail ?? '',
      bankRef:   _paymentId,
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

  void _copyId(BuildContext ctx) {
    Clipboard.setData(ClipboardData(text: _paymentId));
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Payment ID copied!')));
  }

  @override
  Widget build(BuildContext context) {
    final dark    = _isDark(context);
    final textPri = dark ? const Color(0xFFF5F7FA) : const Color(0xFF1A1A2E);
    final textSec = dark ? const Color(0xFF98A1AE) : const Color(0xFF6B7280);
    final card    = dark ? const Color(0xFF1B1F26) : Colors.white;
    final border  = dark ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB);
    const purple  = Color(0xFF7B6CF6);
    const orange  = Color(0xFFFF5A1F);
    const green   = Color(0xFF22C55E);

    final payments   = context.watch<PaymentProvider>().userPayments;
    final hasPending = payments.any((p) => p.status == 'pending');

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101216) : const Color(0xFFF2F3F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 24, 20, 24 + MediaQuery.of(context).padding.bottom),
          children: [

            // ── Header ─────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B6CF6), Color(0xFF5B4CD6)]),
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

            // ── Price card ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF7B6CF6), Color(0xFF5B4CD6)]),
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
              // ── Pending confirmation ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: green.withOpacity(0.35))),
                child: Column(children: [
                  const Icon(Icons.hourglass_top_rounded, color: green, size: 40),
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

              // ── Step 1: Your Payment ID ─────────────────────────────────
              Text('Step 1 — Copy your Payment ID',
                style: TextStyle(
                  color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'This unique ID identifies your payment. You MUST paste it '
                'in the description/note when you send money.',
                style: TextStyle(color: textSec, fontSize: 13, height: 1.45)),
              const SizedBox(height: 14),

              // ID card
              GestureDetector(
                onTap: () => _copyId(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: purple.withOpacity(0.4), width: 1.5)),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _paymentId,
                        style: const TextStyle(
                          color: purple,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.copy_rounded, color: purple, size: 20)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Tap the box to copy',
                  style: TextStyle(color: textSec, fontSize: 12))),
              const SizedBox(height: 24),

              // ── Step 2: Bank transfer ───────────────────────────────────
              Text('Step 2 — Transfer ₮9,900 to this account',
                style: TextStyle(
                  color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border)),
                child: Column(children: [
                  _BankRow('Bank',         _bankName,    textPri, textSec),
                  const SizedBox(height: 10),
                  _BankRow('Account No.',  _accountNo,   textPri, textSec,
                    copyable: true),
                  const SizedBox(height: 10),
                  _BankRow('Account Name', _accountName, textPri, textSec),
                  const SizedBox(height: 10),
                  _BankRow('Amount',       '₮9,900',     textPri, textSec,
                    valueColor: orange),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: orange.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                        color: orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Paste your ID "$_paymentId" in the description/note '
                          'when sending money.',
                          style: TextStyle(
                            color: textPri, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Step 3: Notify us ───────────────────────────────────────
              Text('Step 3 — Notify us after paying',
                style: TextStyle(
                  color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'After completing the transfer, tap the button below. '
                'Admin will match your ID and approve within 24 hours.',
                style: TextStyle(color: textSec, fontSize: 13, height: 1.45)),
              const SizedBox(height: 16),

              Builder(builder: (ctx) {
                final loading = ctx.watch<PaymentProvider>().isLoading;
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
                        : const Text("I've Paid — Notify Admin",
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                );
              }),
            ],

            // ── Past payments ───────────────────────────────────────────────
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Payment History',
                style: TextStyle(
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
                      Text('ID: ${p.bankRef}',
                        style: TextStyle(
                          color: textPri,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1.5)),
                      Text(p.status.toUpperCase(),
                        style: TextStyle(
                          color: c, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                      if (p.status == 'rejected' && p.note?.isNotEmpty == true)
                        Text('Note: ${p.note}',
                          style: const TextStyle(
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
          const Icon(Icons.copy_rounded, color: Color(0xFF7B6CF6), size: 14),
        ],
      ]),
    ),
  ]);
}

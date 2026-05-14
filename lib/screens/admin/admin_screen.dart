import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;

const _purple = Color(0xFF7B6CF6);
const _orange = Color(0xFFFF5A1F);
const _green  = Color(0xFF22C55E);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _filter = 'pending'; // 'pending' | 'all'

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      setState(() => _filter = _tab.index == 0 ? 'pending' : 'all');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PaymentProvider>().startAllPaymentsListener();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    context.read<PaymentProvider>().stopAllPaymentsListener();
    super.dispose();
  }

  Future<void> _approve(PaymentModel p) async {
    final adminId = context.read<AppAuthProvider>().currentUserId ?? '';
    final ok = await context.read<PaymentProvider>().approvePayment(
      paymentId: p.id, userId: p.userId, adminId: adminId);
    if (!mounted) return;
    if (ok) {
      _snack('✓ Approved — user gets 30 days');
    } else {
      final err = context.read<PaymentProvider>().errorMessage ?? 'Failed to approve';
      _snack('Error: $err');
    }
  }

  Future<void> _reject(PaymentModel p) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Reject payment?'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Optional note to user'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Reject',
              style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final adminId = context.read<AppAuthProvider>().currentUserId ?? '';
    final ok = await context.read<PaymentProvider>().rejectPayment(
      paymentId: p.id, adminId: adminId,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    if (!mounted) return;
    _snack(ok ? 'Payment rejected' : 'Failed to reject');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final dark    = _isDark(context);
    final textPri = dark ? const Color(0xFFF5F7FA) : const Color(0xFF1A1A2E);
    final textSec = dark ? const Color(0xFF98A1AE) : const Color(0xFF6B7280);
    final card    = dark ? const Color(0xFF1B1F26) : Colors.white;
    final border  = dark ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB);
    final bg      = dark ? const Color(0xFF101216) : const Color(0xFFF2F3F8);
    final soft    = dark ? const Color(0xFF252A33) : const Color(0xFFF0F1F8);

    final provider   = context.watch<PaymentProvider>();
    final allPay     = provider.allPayments;
    final pendingPay = provider.pendingPayments;
    final displayed  = _filter == 'pending' ? pendingPay : allPay;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Admin — Payments',
          style: TextStyle(
            color: textPri, fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPri),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _purple,
          labelColor: _purple,
          unselectedLabelColor: textSec,
          tabs: [
            Tab(text: 'Pending (${pendingPay.length})'),
            Tab(text: 'All (${allPay.length})'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : displayed.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined,
                    color: textSec, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    _filter == 'pending'
                        ? 'No pending payments'
                        : 'No payments yet',
                    style: TextStyle(color: textSec, fontSize: 15)),
                ]))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
                  itemCount: displayed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _PaymentCard(
                    payment: displayed[i],
                    card: card, border: border, textPri: textPri,
                    textSec: textSec, soft: soft,
                    onApprove: displayed[i].status == 'pending'
                        ? () => _approve(displayed[i]) : null,
                    onReject: displayed[i].status == 'pending'
                        ? () => _reject(displayed[i]) : null,
                  ),
                ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  final Color card, border, textPri, textSec, soft;
  final VoidCallback? onApprove, onReject;
  const _PaymentCard({
    required this.payment,
    required this.card, required this.border,
    required this.textPri, required this.textSec,
    required this.soft,
    this.onApprove, this.onReject,
  });

  Color get _statusColor {
    switch (payment.status) {
      case 'approved': return _green;
      case 'rejected': return Colors.redAccent;
      default:         return _orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // User info row
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(
              child: Text(
                payment.userName.isNotEmpty
                    ? payment.userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: _purple, fontWeight: FontWeight.w700, fontSize: 18)))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(payment.userName,
              style: TextStyle(
                color: textPri, fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(payment.userEmail,
              style: TextStyle(color: textSec, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Text(payment.status.toUpperCase(),
              style: TextStyle(
                color: _statusColor, fontSize: 11,
                fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        // Details
        _Row('Amount', '₮${payment.amount.toStringAsFixed(0)}',
          textSec, textPri),
        const SizedBox(height: 4),
        _Row('Reference', payment.bankRef, textSec, textPri),
        const SizedBox(height: 4),
        _Row('Submitted', _fmt(payment.submittedAt), textSec, textSec),
        if (payment.status == 'approved' && payment.processedAt != null) ...[
          const SizedBox(height: 4),
          _Row('Approved', _fmt(payment.processedAt), textSec, _green),
        ],
        if (payment.status == 'rejected' && payment.note?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          _Row('Note', payment.note!, textSec, Colors.redAccent),
        ],
        // Action buttons
        if (onApprove != null || onReject != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            if (onReject != null)
              Expanded(child: GestureDetector(
                onTap: onReject,
                child: Container(height: 42, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3))),
                  child: const Text('Reject',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700, fontSize: 13))),
              )),
            if (onApprove != null && onReject != null)
              const SizedBox(width: 10),
            if (onApprove != null)
              Expanded(child: GestureDetector(
                onTap: onApprove,
                child: Container(height: 42, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _green.withOpacity(0.35))),
                  child: const Text('Approve (+30 days)',
                    style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700, fontSize: 13))),
              )),
          ]),
        ],
      ]),
    );
  }

  Widget _Row(String label, String value, Color lc, Color vc) =>
      Row(children: [
        Text('$label: ', style: TextStyle(color: lc, fontSize: 13)),
        Expanded(child: Text(value,
          style: TextStyle(
            color: vc, fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]);

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

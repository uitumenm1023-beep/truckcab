import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final sellerId = authProvider.currentUserId;

      if (sellerId != null && sellerId.isNotEmpty) {
        chatProvider.startSellerChatRequestsListener(sellerId);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<ChatProvider>().stopSellerChatRequestsListener();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _openChat({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final chatProvider = context.read<ChatProvider>();

    final success = await chatProvider.acceptChatRequest(
      requestId: requestId,
      requestData: requestData,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat opened. You can talk before final delivery approval.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatProvider.errorMessage ?? 'Failed to open chat',
          ),
        ),
      );
    }
  }

  Future<void> _finalApprove({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final chatProvider = context.read<ChatProvider>();

    final success = await chatProvider.confirmDriverForDelivery(
      requestId: requestId,
      requestData: requestData,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver approved for final delivery.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatProvider.errorMessage ?? 'Failed to approve driver',
          ),
        ),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final chatProvider = context.read<ChatProvider>();

    final success = await chatProvider.rejectChatRequest(requestId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatProvider.errorMessage ?? 'Failed to reject request',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Requests'),
      ),
      body: chatProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatProvider.chatRequests.isEmpty
              ? const Center(
                  child: Text('No delivery requests'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.chatRequests.length,
                  itemBuilder: (context, index) {
                    final doc = chatProvider.chatRequests[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final orderDescription =
                        (data['orderDescription'] ?? '').toString();
                    final pickupLocation =
                        (data['pickupLocation'] ?? '').toString();
                    final dropoffLocation =
                        (data['dropoffLocation'] ?? '').toString();
                    final driverId = (data['driverId'] ?? '').toString();
                    final status = (data['status'] ?? '').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderDescription.isEmpty
                                  ? 'Delivery Request'
                                  : orderDescription,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('Pickup: $pickupLocation'),
                            Text('Dropoff: $dropoffLocation'),
                            Text('Driver ID: $driverId'),
                            Text('Request Status: $status'),
                            const SizedBox(height: 8),
                            if (status == 'pending')
                              const Text(
                                'Step 1: open chat first.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            if (status == 'chat_open')
                              const Text(
                                'Step 2: after chatting, approve this driver for final delivery.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 14),
                            if (status == 'pending') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _openChat(
                                        requestId: doc.id,
                                        requestData: data,
                                      ),
                                      child: const Text('Accept & Open Chat'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _rejectRequest(doc.id),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (status == 'chat_open') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _finalApprove(
                                        requestId: doc.id,
                                        requestData: data,
                                      ),
                                      child: const Text('Final Approve Driver'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _rejectRequest(doc.id),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
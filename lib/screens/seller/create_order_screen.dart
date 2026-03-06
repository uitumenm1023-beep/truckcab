import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/validators.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await orderProvider.createOrder(
      sellerId: authProvider.currentUserId ?? '',
      pickupLocation: _pickupController.text.trim(),
      dropoffLocation: _dropoffController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim()),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created successfully')),
      );

      Navigator.pop(context);
    } else {
      final message = orderProvider.errorMessage ?? 'Failed to create order';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Delivery Order"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              TextFormField(
                controller: _pickupController,
                decoration: const InputDecoration(
                  labelText: "Pickup Location",
                ),
                validator: (value) =>
                    Validators.validateText(value, "Pickup Location"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _dropoffController,
                decoration: const InputDecoration(
                  labelText: "Dropoff Location",
                ),
                validator: (value) =>
                    Validators.validateText(value, "Dropoff Location"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Package Description",
                ),
                validator: (value) =>
                    Validators.validateText(value, "Description"),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "Delivery Price",
                ),
                keyboardType: TextInputType.number,
                validator: Validators.validatePrice,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: orderProvider.isLoading ? null : _createOrder,
                  child: orderProvider.isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Create Order"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
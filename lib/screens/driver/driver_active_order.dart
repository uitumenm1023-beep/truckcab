import 'package:flutter/material.dart';

class DriverActiveOrder extends StatelessWidget {
  const DriverActiveOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Active Order'),
      ),
      body: const Center(
        child: Text(
          'This screen is currently not used.\nUse Driver Home > Active tab instead.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
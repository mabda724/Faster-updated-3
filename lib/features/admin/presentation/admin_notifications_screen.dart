import 'package:flutter/material.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: const Center(child: Text('لا توجد إشعارات جديدة')),
    );
  }
}

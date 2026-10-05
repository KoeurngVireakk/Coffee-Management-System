import 'package:flutter/material.dart';

class CoffeeManagementApp extends StatelessWidget {
  const CoffeeManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Coffee Management System',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(child: Center(child: Text('Coffee Management System'))),
      ),
    );
  }
}

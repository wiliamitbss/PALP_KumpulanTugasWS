import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.purple[100],
      ),
      body: Center(
        child: const Text(
          'This is Home Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

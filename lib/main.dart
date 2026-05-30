import 'package:flutter/material.dart';
import 'view/profile_screen.dart';

void main() {

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexus',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: const ProfileScreen(),
    );
  }
}
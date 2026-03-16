import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ChangeYourLifeApp());
}

class ChangeYourLifeApp extends StatelessWidget {
  const ChangeYourLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Change Your Life in Community',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HomeScreen(),
    );
  }
}
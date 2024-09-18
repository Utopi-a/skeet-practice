import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(SkeetPracticeApp());
}

class SkeetPracticeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'スキート射撃練習',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

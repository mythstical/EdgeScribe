import 'package:flutter/material.dart';
import 'package:edgescribe/pages/redactor_page.dart';

void main() {
  runApp(const EdgeScribeApp());
}

class EdgeScribeApp extends StatelessWidget {
  const EdgeScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeScribe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D9FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RedactorPage(),
    );
  }
}

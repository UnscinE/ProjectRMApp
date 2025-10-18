// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/auth_gate.dart';
                 // << ตรงนี้สำคัญ ชี้มาที่ lib/src/auth_gate.dart
import 'package:timezone/data/latest.dart' as tzdata;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RunningApp());
}

class RunningApp extends StatelessWidget {
  const RunningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const AuthGate(),                   // << ใช้คลาส AuthGate
    );
  }
}

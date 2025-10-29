import 'dart:async';
import 'package:flutter/material.dart';

class CountdownOverlayExample extends StatefulWidget {
  const CountdownOverlayExample({super.key});

  @override
  State<CountdownOverlayExample> createState() =>
      _CountdownOverlayExampleState();
}

class _CountdownOverlayExampleState extends State<CountdownOverlayExample> {
  int _countdown = 0;
  bool _showOverlay = false;

  void _startCountdown() {
    if (_showOverlay) return; // ป้องกันกดซ้ำ

    setState(() {
      _countdown = 3;
      _showOverlay = true;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _showOverlay = false;
        });

        // ✅ เรียกฟังก์ชันต่อไปได้ตรงนี้
        _startTraining();
      }
    });
  }

  void _startTraining() {
    print('🏃 Training Started!');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Training started!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Overlay Countdown Example")),
      body: Stack(
        children: [
          // หน้าจอหลักของคุณ
          Center(
            child: ElevatedButton(
              onPressed: _startCountdown,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 60,
                ),
                backgroundColor: Colors.lightBlueAccent,
              ),
              child: const Text(
                'Start',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),

          // 🔢 Overlay แสดงนับถอยหลังตรงกลางจอ
          if (_showOverlay)
            Container(
              color: Colors.black54, // พื้นหลังโปร่งดำ
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _countdown > 0 ? '$_countdown' : 'GO!',
                    style: const TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.blueAccent,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

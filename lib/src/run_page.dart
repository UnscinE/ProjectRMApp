import 'dart:async';
import 'package:flutter/material.dart';

class RunPage extends StatefulWidget {
  const RunPage({super.key});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> {
  Timer? _timer;
  int _secs = 0;
  double _distance = 0; // km (mock เพิ่ม 0.01 ทุก 3 วินาที)
  bool _running = false;

  void _start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secs++;
        if (_secs % 3 == 0) _distance += 0.01; // mock วิ่ง
      });
    });
    setState(() {});
  }

  void _stop() {
    _running = false;
    _timer?.cancel();
    setState(() {});
  }

  void _reset() {
    _stop();
    setState(() {
      _secs = 0;
      _distance = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pace = _distance > 0 ? Duration(seconds: (_secs / _distance).round()) : null;
    final paceStr = pace == null ? '-' : '${pace.inMinutes}:${(pace.inSeconds%60).toString().padLeft(2,'0')} /Km';

    return Scaffold(
      appBar: AppBar(title: const Text('Running')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220, height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: (_secs % 60)/60, strokeWidth: 12),
                    Text(_mmss, style: Theme.of(context).textTheme.displayMedium),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('ระยะทาง: ${_distance.toStringAsFixed(2)} km'),
              Text('เพซเฉลี่ย: $paceStr'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: _running ? null : _start,
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _running ? _stop : null,
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final pace =
        _distance > 0 ? Duration(seconds: (_secs / _distance).round()) : null;
    final paceStr = pace == null
        ? '-'
        : '${pace.inMinutes}:${(pace.inSeconds % 60).toString().padLeft(2, '0')} /Km';

    final theme = Theme.of(context);
    final percent = (_secs % 60) / 60.0;

    return Scaffold(
      // ==== AppBar (แต่งโทนส้ม) ====
      appBar: AppBar(
        title: const Text('Running'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF212121),
      ),

      // ==== พื้นหลังไล่สีเทาอ่อน ====
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==== วงแหวนเวลาแบบกราเดียนต์ส้ม ====
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF6F00).withOpacity(.08),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // วงแหวนพื้นหลัง
                        CustomPaint(
                          size: const Size.square(240),
                          painter: _RingPainter(
                            percent: 1,
                            colorBg: const Color(0xFFEEEEEE),
                            gradient: const LinearGradient(colors: [
                              Color(0xFFEEEEEE),
                              Color(0xFFEEEEEE),
                            ]),
                          ),
                        ),
                        // วงแหวนค่าจริง
                        CustomPaint(
                          size: const Size.square(240),
                          painter: _RingPainter(
                            percent: percent,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                            ),
                          ),
                        ),
                        // เวลา
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _mmss,
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                color: const Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'รอบ 60 วิ',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF757575),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==== การ์ดสรุประยะทาง & เพซ (โทนส้ม) ====
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.route,
                        title: 'ระยะทาง',
                        valueTop: _distance.toStringAsFixed(2),
                        valueBottom: 'กม.',
                        color: const Color(0xFFFF6F00),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.speed,
                        title: 'เพซเฉลี่ย',
                        valueTop: paceStr.split(' ').first,
                        valueBottom: paceStr.contains(' ')
                            ? paceStr.split(' ').last
                            : '/Km',
                        color: const Color(0xFFFF8F00),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ==== ปุ่มควบคุม (สไตล์ตามธีม) ====
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Start — กดได้เมื่อยังไม่เริ่ม
                    Expanded(
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _running
                              ? const LinearGradient(
                                  colors: [Color(0xFFBDBDBD), Color(0xFFBDBDBD)],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                                ),
                          boxShadow: [
                            if (!_running)
                              BoxShadow(
                                color: const Color(0xFFFF6F00).withOpacity(.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: _running ? null : _start,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            'เริ่ม',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Stop — สีแดง
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _running ? _stop : null,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('หยุด'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor:
                              _running ? const Color(0xFFE53935) : const Color(0xFFE0E0E0),
                          foregroundColor: Colors.white,
                          elevation: _running ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Reset — เส้นขอบส้ม
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restore),
                        label: const Text('รีเซ็ต'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: Color(0xFFFF6F00), width: 2),
                          foregroundColor: const Color(0xFFFF6F00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ======= Painter วงแหวนกราเดียนต์ (ใช้เฉพาะเรื่องสไตล์) =======
class _RingPainter extends CustomPainter {
  final double percent; // 0..1
  final LinearGradient gradient;
  final double stroke;
  final Color? colorBg;

  _RingPainter({
    required this.percent,
    required this.gradient,
    this.stroke = 14,
    this.colorBg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    // BG circle (optional)
    if (colorBg != null) {
      final bgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colorBg!;
      canvas.drawCircle(center, radius, bgPaint);
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    const startDeg = -90.0; // เริ่มบนสุด
    final sweep = 2 * 3.141592653589793 * percent;
    canvas.drawArc(rect, startDeg * (3.1415926535 / 180), sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.stroke != stroke || old.gradient != gradient;
}

/// ======= การ์ดสถิติเล็ก (Orange Premium Style) =======
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueTop;
  final String valueBottom;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.valueTop,
    required this.valueBottom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(.9)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF757575),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF212121),
                height: 1.1,
                letterSpacing: -0.7,
              ),
              children: [
                TextSpan(text: '$valueTop\n'),
                TextSpan(
                  text: valueBottom,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF616161),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

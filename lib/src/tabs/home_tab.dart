import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// อ่านปฏิทิน
import 'package:device_calendar/device_calendar.dart' as devcal;
import 'package:timezone/timezone.dart' as tz;

class DashboardTab extends StatefulWidget {
  final int targetKm;
  final int trainingWeeks;
  final VoidCallback onContinue;
  final String email;

  const DashboardTab({
    super.key,
    required this.targetKm,
    required this.trainingWeeks,
    required this.onContinue,
    required this.email,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  // data UI
  final distance = 5.0; // (mock — ใส่จริงภายหลัง)
  final pace = '6:11 / Km'; // (mock)
  final totalTime = '30:59 นาที'; // (mock)
  final successPercent = 0.50; // 0..1 (mock)

  String? _calendarTitle; // ชื่อเล่มที่ใช้อยู่ (โชว์บนการ์ดเล็ก ๆ)
  List<String>? _todayItems; // รายการที่ "ตรงกับปฏิทินวันนี้"
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTodayFromDeviceCalendar();
  }

  Future<void> _loadTodayFromDeviceCalendar() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final plugin = devcal.DeviceCalendarPlugin();

    try {
      // ขอสิทธิ์
      final perms = await plugin.requestPermissions();
      if (perms.data != true) {
        setState(() {
          _todayItems = const [];
          _calendarTitle = null;
          _error = 'ยังไม่ได้อนุญาตสิทธิ์ปฏิทิน';
          _loading = false;
        });
        return;
      }

      // เล่มที่เลือกไว้ (เราเคยเซฟ key 'calendarId')
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString('calendarId');

      // ดึงรายชื่อเล่มทั้งหมด (เขียนได้/อ่านได้)
      final calsResult = await plugin.retrieveCalendars();
      final cals = (calsResult.data ?? <devcal.Calendar>[])
          .where((c) => c.isReadOnly != true)
          .toList();

      if (cals.isEmpty) {
        setState(() {
          _todayItems = const [];
          _calendarTitle = null;
          _loading = false;
        });
        return;
      }

      // เลือกเล่มเป้าหมาย: ถ้ามี id ที่เลือกไว้ใช้เลย ไม่งั้นใช้ตัวแรก
      final devcal.Calendar targetCal = selectedId != null
          ? (cals.firstWhere(
              (c) => c.id == selectedId,
              orElse: () => cals.first,
            ))
          : cals.first;

      // ตั้งหัวข้อเล่มเพื่อโชว์ใต้การ์ด
      _calendarTitle = [
        (targetCal.name ?? 'Calendar'),
        if ((targetCal.accountName ?? '').isNotEmpty)
          '• ${targetCal.accountName}',
      ].join(' ');

      // ช่วงวันนี้ (00:00 - 23:59:59)
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      final tzStart = tz.TZDateTime.from(dayStart, tz.local);
      final tzEnd = tz.TZDateTime.from(dayEnd, tz.local);

      final eventsRes = await plugin.retrieveEvents(
        targetCal.id!,
        devcal.RetrieveEventsParams(
          startDate: tzStart,
          endDate: tzEnd,
          // includeOccurrences: true,  // <-- ลบออกถ้าฟ้องแดง
        ),
      );

      final events = eventsRes.data ?? <devcal.Event>[];

      // map รายการสำหรับโชว์ (ใช้ title + (description ถ้ามีสั้น ๆ))
      final items = <String>[];
      for (final e in events) {
        final title = (e.title ?? '').trim();
        final desc = (e.description ?? '').trim();
        if (title.isEmpty && desc.isEmpty) continue;

        if (desc.isEmpty) {
          items.add(title);
        } else if (title.isEmpty) {
          items.add(desc);
        } else {
          // title • desc บรรทัดเดียวแบบสั้น
          final shortDesc = desc.replaceAll('\n', ' ');
          items.add('$title • $shortDesc');
        }
      }

      setState(() {
        _todayItems = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _todayItems = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFAFAFA),
            Color(0xFFF5F5F5),
            Color(0xFFEEEEEE),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // หัวเรื่อง + วันที่
            Text(
              'ภาพรวมการฝึก',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: const Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${today.day} ${_thaiMonth(today.month)} ${today.year + 543}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF757575),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 32),

            // KPI 3 ช่อง
            Row(
              children: [
                _KpiTile(
                  icon: Icons.route,
                  title: 'ระยะทาง',
                  valueTop: distance.toStringAsFixed(2),
                  valueBottom: 'กม.',
                  color: const Color(0xFFFF6F00),
                ),
                const SizedBox(width: 12),
                _KpiTile(
                  icon: Icons.speed,
                  title: 'เพซเฉลี่ย',
                  valueTop: '6:11',
                  valueBottom: '/Km',
                  color: const Color(0xFFF57C00),
                ),
                const SizedBox(width: 12),
                _KpiTile(
                  icon: Icons.schedule,
                  title: 'เวลารวม',
                  valueTop: '30:59',
                  valueBottom: 'นาที',
                  color: const Color(0xFFFF9800),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // วงแหวนเปอร์เซ็นต์
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF6F00).withOpacity(.12),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: _RingProgress(
                  size: 200,
                  percent: successPercent,
                  stroke: 18,
                  bgOpacity: .10,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // สัปดาห์
            _WeekStrip(current: 1, total: widget.trainingWeeks),

            const SizedBox(height: 28),

            // แผนวันนี้จาก "ปฏิทินจริง"
            _TodayPlanCard(
              title: 'แผนวันนี้',
              items: _buildTodayItemsForUi(),
              calendarTitle: _calendarTitle,
              loading: _loading,
              error: _error,
              onRefresh: _loadTodayFromDeviceCalendar,
            ),

            const SizedBox(height: 20),
            Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF6F00),
                    Color(0xFFFF8F00),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6F00).withOpacity(.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: widget.onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  'เริ่มฝึก / บันทึกการฝึก',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _buildTodayItemsForUi() {
    if (_loading) return const [];
    if (_todayItems == null) return const [];
    if (_todayItems!.isEmpty) return const ['วันนี้ไม่มีรายการในปฏิทิน'];
    // จำกัด 5 บรรทัดสวย ๆ
    return _todayItems!.take(5).toList();
  }

  String _thaiMonth(int m) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return months[m - 1];
  }
}

/// ---------- UI widgets (Premium Orange-Gray Theme) ----------

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueTop;
  final String valueBottom;
  final Color color;

  const _KpiTile({
    required this.icon,
    required this.title,
    required this.valueTop,
    required this.valueBottom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
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
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.85),
                  ],
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
              child: Icon(
                icon,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
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
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  final double size;
  final double percent; // 0..1
  final double stroke;
  final double bgOpacity;

  const _RingProgress({
    required this.size,
    required this.percent,
    this.stroke = 14,
    this.bgOpacity = .2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent.clamp(0.0, 1.0),
          stroke: stroke,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF6F00),
                    Color(0xFFFF8F00),
                  ],
                ).createShader(bounds),
                child: Text(
                  '${(percent * 100).round()}%',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: 0.95,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ความสำเร็จ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF757575),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double stroke;

  _RingPainter({
    required this.percent,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEEEEEE)
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF6F00),
          Color(0xFFFF8F00),
          Color(0xFFFFA726),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final startAngle = -90 * (3.1415926535 / 180); // -90°
    final sweep = 2 * 3.1415926535 * percent;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.stroke != stroke;
}

class _WeekStrip extends StatelessWidget {
  final int current;
  final int total;
  const _WeekStrip({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            'สัปดาห์',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF212121),
              letterSpacing: -0.4,
            ),
          ),
        ),
        Row(
          children: List.generate(total, (i) {
            final idx = i + 1;
            final selected = idx == current;
            return Expanded(
              child: Container(
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFF6F00),
                            Color(0xFFFF8F00),
                          ],
                        )
                      : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? null
                      : Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 2,
                        ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: const Color(0xFFFF6F00).withOpacity(.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$idx',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF757575),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TodayPlanCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? calendarTitle;
  final bool loading;
  final String? error;
  final VoidCallback? onRefresh;

  const _TodayPlanCard({
    required this.title,
    required this.items,
    this.calendarTitle,
    this.loading = false,
    this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF6F00),
                      Color(0xFFFF8F00),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6F00).withOpacity(.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flag,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: const Color(0xFF212121),
                ),
              ),
              const Spacer(),
              if (calendarTitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Text(
                    calendarTitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF757575),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (onRefresh != null) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF6F00),
                        Color(0xFFFF8F00),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6F00).withOpacity(.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'รีเฟรชจากปฏิทิน',
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: onRefresh,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFFFF6F00),
                  ),
                ),
              ),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'เกิดข้อผิดพลาด: $error',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF6F00),
                            Color(0xFFFF8F00),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6F00).withOpacity(.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          letterSpacing: 0.2,
                          color: const Color(0xFF424242),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
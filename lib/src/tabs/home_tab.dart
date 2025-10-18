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
  List<String>? _todayItems; // รายการที่ “ตรงกับปฏิทินวันนี้”
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // หัวเรื่อง + วันที่
          Text(
            'การวิ่ง',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${today.day} ${_thaiMonth(today.month)} ${today.year + 543}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(.55),
            ),
          ),

          const SizedBox(height: 16),

          // KPI 3 ช่อง
          Row(
            children: [
              _KpiTile(
                icon: Icons.route_outlined,
                title: 'ระยะทาง',
                valueTop: distance.toStringAsFixed(2),
                valueBottom: 'กม.',
              ),
              const SizedBox(width: 12),
              _KpiTile(
                icon: Icons.timer_outlined,
                title: 'เพซเฉลี่ย',
                valueTop: '6:11 /',
                valueBottom: 'Km',
              ),
              const SizedBox(width: 12),
              _KpiTile(
                icon: Icons.schedule_outlined,
                title: 'เวลารวม',
                valueTop: '30:59',
                valueBottom: 'นาที',
              ),
            ],
          ),

          const SizedBox(height: 22),

          // วงแหวนเปอร์เซ็นต์
          Center(
            child: _RingProgress(
              size: 220,
              percent: successPercent,
              stroke: 16,
              bgOpacity: .18,
            ),
          ),

          const SizedBox(height: 16),

          // สัปดาห์
          _WeekStrip(current: 1, total: widget.trainingWeeks),

          const SizedBox(height: 20),

          // แผนวันนี้จาก "ปฏิทินจริง"
          _TodayPlanCard(
            title: 'แผนวันนี้',
            items: _buildTodayItemsForUi(),
            calendarTitle: _calendarTitle,
            loading: _loading,
            error: _error,
            onRefresh: _loadTodayFromDeviceCalendar,
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: widget.onContinue,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('เริ่มฝึก / บันทึกการฝึก'),
            ),
          ),
        ],
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

/// ---------- UI widgets (เหมือนเวอร์ชันก่อน แต่ย้ายมาใช้ร่วม) ----------

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueTop;
  final String valueBottom;

  const _KpiTile({
    required this.icon,
    required this.title,
    required this.valueTop,
    required this.valueBottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outlineVariant.withOpacity(.5);
    final onSurface = theme.colorScheme.onSurface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(.04),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: onSurface.withOpacity(.6),
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                  height: 1.2,
                ),
                children: [
                  TextSpan(text: '$valueTop\n'),
                  TextSpan(
                    text: valueBottom,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onSurface,
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
    final fg = theme.colorScheme.tertiary;
    final bg = theme.colorScheme.onSurface.withOpacity(bgOpacity);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent.clamp(0.0, 1.0),
          stroke: stroke,
          fg: fg,
          bg: bg,
        ),
        child: Center(
          child: Text(
            '${(percent * 100).round()}',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double stroke;
  final Color fg;
  final Color bg;

  _RingPainter({
    required this.percent,
    required this.stroke,
    required this.fg,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = bg
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = fg
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final startAngle = -90 * (3.1415926535 / 180); // -90°
    final sweep = 2 * 3.1415926535 * percent;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent ||
      old.fg != fg ||
      old.bg != bg ||
      old.stroke != stroke;
}

class _WeekStrip extends StatelessWidget {
  final int current;
  final int total;
  const _WeekStrip({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: List.generate(total, (i) {
        final idx = i + 1;
        final selected = idx == current;
        return Expanded(
          child: Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(.20)
                  : theme.colorScheme.surfaceVariant.withOpacity(.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withOpacity(.45)
                    : Colors.transparent,
              ),
            ),
            child: Center(
              child: Text(
                '$idx',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }),
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
    final subtle = theme.colorScheme.onSurface.withOpacity(.55);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (calendarTitle != null)
                Text(
                  calendarTitle!,
                  style: theme.textTheme.labelMedium?.copyWith(color: subtle),
                ),
              if (onRefresh != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'รีเฟรชจากปฏิทิน',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'เกิดข้อผิดพลาด: $error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else
            ...items.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

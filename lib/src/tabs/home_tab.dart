import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rmapp/src/training_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Device calendar
import 'package:device_calendar/device_calendar.dart' as devcal;
import 'package:timezone/data/latest.dart' as tz;
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
  String _targetPaceText = 'N/A';
  int _timeTargetSec = 0;
  String _Totaltime = 'N/A';
  // mock (แสดง KPI)

  // Program & progress (จริง)
  String? _currentProgramId;
  double _averageSuccessPercent = 0.0; // 0..1

  // calendar today
  String? _calendarTitle; // title เล่ม
  List<String> _todayItems = const []; // รายการวันนี้
  bool _loading = true;
  String? _error;

  // แผนของวันนี้
  String _runningType = 'Long Run';
  String _runningTargetText = 'N/A'; // เช่น "3 KM"
  int _timeTargetMin = 0; // นาที
  double _targetDistanceKm = 0.0; // กิโลเมตร (parse จาก _runningTargetText)

  // ค่าขณะฝึก
  bool _isTraining = false;
  String _activity = 'getting data';
  double _distanceKm = 0.0; // ระยะทางที่ทำได้ (km)
  String _speedKmhText = '0.00';

  late String formattedPace; // แสดงบน UI

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _loadInitialData();
    _loadProgramId();
  }

  Future<void> _loadInitialData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    // เลือก program id แบบง่าย ๆ (คุณจะเปลี่ยนให้ดึงจริงจาก repo ก็ได้)
    _currentProgramId ??= '3AUgieOoHsrQ8Bl8AcTl';

    await _loadTodayFromDeviceCalendar();
    if (userId != null && _currentProgramId != null) {
      await _calculateAverageSuccess(userId, _currentProgramId!);
    }
  }

  Future<void> _calculateAverageSuccess(String userId, String programId) async {
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Program')
          .doc(programId)
          .collection('Training');

      final q = await col.get();
      if (q.docs.isEmpty) {
        if (mounted) setState(() => _averageSuccessPercent = 0);
        return;
      }

      double sum = 0;
      int days = 0;

      for (final d in q.docs) {
        if (d.data()['type'] != 'Rest') {
          final raw = d.data()['progress_bar_percent'];
          double v = switch (raw) {
            int x => x.toDouble(),
            double x => x,
            String s => double.tryParse(s) ?? 0.0,
            _ => 0.0,
          };
          sum += v; // v เป็น 0..100
          days ++;
          print(days);
        }
      }

      final avg100 = days == 0 ? 0.0 : sum / days;
      if (mounted) {
        setState(() => _averageSuccessPercent = (avg100 / 100).clamp(0, 1));
      }
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _loadTodayFromDeviceCalendar() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final plugin = devcal.DeviceCalendarPlugin();

    try {
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

      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString('calendarId');

      final calsRes = await plugin.retrieveCalendars();
      final cals = (calsRes.data ?? <devcal.Calendar>[])
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

      final target = selectedId != null
          ? (cals.firstWhere(
              (c) => c.id == selectedId,
              orElse: () => cals.first,
            ))
          : cals.first;

      _calendarTitle = [
        target.name ?? 'Calendar',
        if ((target.accountName ?? '').isNotEmpty) '• ${target.accountName}',
      ].join(' ');

      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      final tzStart = tz.TZDateTime.from(dayStart, tz.local);
      final tzEnd = tz.TZDateTime.from(dayEnd, tz.local);

      final evRes = await plugin.retrieveEvents(
        target.id!,
        devcal.RetrieveEventsParams(startDate: tzStart, endDate: tzEnd),
      );
      final events = evRes.data ?? <devcal.Event>[];

      final items = <String>[];
      for (final e in events) {
        final t = (e.title ?? '').trim();
        final d = (e.description ?? '').trim().replaceAll('\n', ' ');
        if (t.isEmpty && d.isEmpty) continue;
        items.add(t.isEmpty ? d : (d.isEmpty ? t : '$t • $d'));
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

  //----------- Data load ------------
  Future<void> _loadProgramId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ต้องมีเมธอดนี้ใน training_repo.dart
    final programIdList = await TrainingRepo.fetchCurrentProgramId(user.uid);
    setState(() => _currentProgramId = programIdList?.first);

    if (_currentProgramId != null) {
      await _loadTodayPlan();
      Calculatepace();
    }
  }

  Future<void> _loadTodayPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    // ใช้ฟอร์แมตเดียวกับฝั่งบันทึก: dd-MM-yyyy
    final todayId = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(_currentProgramId!)
        .collection('Training')
        .doc(todayId);

    try {
      final snap = await docRef.get();
      if (!snap.exists) {
        setState(() {
          _runningType = 'No Plan';
          _runningTargetText = 'N/A';
          _timeTargetSec = 0; // <<-- เปลี่ยนเป็นตัวแปรสำหรับวินาที
          _targetDistanceKm = 0.0;
        });
        return;
      }

      final data = snap.data()!;
      final distanceText = (data['distance_km']?.toString() ?? '').trim();
      final timeText = (data['duration_s']?.toString() ?? '')
          .trim(); // ตอนนี้ทราบว่าเป็น "วินาที"
      final typeText = (data['type']?.toString() ?? 'Rest').trim();

      //'${paceMinutes}:${paceSeconds.toString().padLeft(2, '0')}
      final timeectext = int.parse(timeText);
      final timemin = timeectext ~/ 60; // นาทีเต็ม
      final timeseconds = timeectext % 60;

      _Totaltime = '${timemin}:${timeseconds.toString().padLeft(2, '0')}';

      // ดึงตัวเลขวินาทีทั้งหมดจาก timeText
      // สมมติว่า timeText มีรูปแบบ เช่น "1260 s" หรือ "21 Min" (ถ้ายังเก็บเป็นนาที แต่ใช้ field เป็น duration_s)
      // **แต่ถ้าแน่ใจว่าเป็นวินาที ให้ดึงเป็นวินาทีทั้งหมด**
      final totalSeconds =
          int.tryParse(timeText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      // ดึงตัวเลขกิโลเมตรจาก distanceText
      final distanceNum =
          double.tryParse(distanceText.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;

      setState(() {
        _runningType = typeText;
        _runningTargetText = distanceNum.toStringAsFixed(2);
        // เปลี่ยนมาใช้ตัวแปรชื่อที่บ่งบอกว่าเป็นวินาที เช่น _timeTargetSec หรือ _totalTargetSeconds
        // **ต้องประกาศตัวแปร int _timeTargetSec ใน State Class ของคุณ**
        _timeTargetSec = totalSeconds;
        _targetDistanceKm = distanceNum;
      });
    } catch (_) {
      setState(() {
        _runningType = 'Error';
        _runningTargetText = 'N/A';
        _timeTargetSec = 0; // <<-- เปลี่ยนเป็นตัวแปรสำหรับวินาที
        _targetDistanceKm = 0.0;
      });
    }
  }

  // อย่าลืมเปลี่ยนชื่อตัวแปร _timeTargetMin เป็น int _timeTargetSec; ใน State Class
  // และเพิ่ม String _targetPaceText; ด้วย

  Future<void> Calculatepace() async {
    // *** แก้ไข: ต้องใช้ await เพื่อรอให้ _loadTodayPlan ดึงข้อมูลเสร็จก่อน ***
    await _loadTodayPlan();

    // ตรวจสอบว่ามีระยะทางเป้าหมายหรือไม่
    if (_targetDistanceKm > 0) {
      // 1. คำนวณเพซเป็นหน่วยวินาทีต่อกิโลเมตร (Sec/Km)
      final paceSecPerKm = _timeTargetSec / _targetDistanceKm;

      // 2. แปลง Pace (Sec/Km) เป็นรูปแบบ นาที:วินาที/กม.
      final totalPaceSeconds = paceSecPerKm
          .round(); // วินาทีทั้งหมดสำหรับ 1 กม. (ปัดเศษ)

      final paceMinutes = totalPaceSeconds ~/ 60; // นาทีเต็ม
      final paceSeconds = totalPaceSeconds % 60; // เศษวินาที

      // 3. จัดรูปแบบให้แสดงผลสวยงาม เช่น "5:30 /Km"
      // ใช้ final String แทนการกำหนดค่าให้ตัวแปรที่ไม่ได้ประกาศ
      final String formattedPace =
          '${paceMinutes}:${paceSeconds.toString().padLeft(2, '0')}';

      setState(() {
        // อัปเดตตัวแปรใน State Class เพื่อแสดงผลใน UI
        _targetPaceText = formattedPace;
        print('Calculated Pace: $formattedPace');
      });
    } else if (_timeTargetSec > 0 && _targetDistanceKm == 0.0) {
      // กรณีมีเวลาเป้าหมาย แต่ไม่มีระยะทางเป้าหมาย (Time Run)
      setState(() {
        _targetPaceText = 'N/A (Time Run)';
        print('Pace N/A (Time Run)');
      });
    } else {
      // กรณีที่ไม่มีทั้งเวลาและระยะทาง (No Plan / Rest)
      setState(() {
        _targetPaceText = 'N/A';
        print('Pace N/A');
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
          colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            const SizedBox(height: 22),

            // KPI 3 ช่อง
            Row(
              children: [
                _KpiTile(
                  icon: Icons.route,
                  title: 'ระยะทาง',
                  valueTop: _runningTargetText,
                  valueBottom: 'กม.',
                  color: const Color(0xFFFF6F00),
                ),
                const SizedBox(width: 12),
                _KpiTile(
                  icon: Icons.speed,
                  title: 'เพซเฉลี่ย',
                  valueTop: _targetPaceText,
                  valueBottom: '/Km',
                  color: const Color(0xFFF57C00),
                ),
                const SizedBox(width: 12),
                _KpiTile(
                  icon: Icons.schedule,
                  title: 'เวลารวม',
                  valueTop: _Totaltime,
                  valueBottom: 'นาที',
                  color: const Color(0xFFFF9800),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // วงแหวนเปอร์เซ็นต์ (เฉลี่ยจริง)
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
                    ),
                  ],
                ),
                child: _RingProgress(
                  size: 200,
                  percent: _averageSuccessPercent,
                  stroke: 18,
                ),
              ),
            ),

            const SizedBox(height: 32),

            _WeekStrip(current: 1, total: widget.trainingWeeks),

            const SizedBox(height: 28),

            _TodayPlanCard(
              title: 'แผนวันนี้',
              items: _loading
                  ? const []
                  : (_todayItems.isEmpty
                        ? const ['วันนี้ไม่มีรายการในปฏิทิน']
                        : _todayItems.take(5).toList()),
              calendarTitle: _calendarTitle,
              loading: _loading,
              error: _error,
              onRefresh: _loadTodayFromDeviceCalendar,
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: widget.onContinue,
                style:
                    FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.all(
                        Colors.transparent,
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

  String _thaiMonth(int m) => const [
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
  ][m - 1];
}

//------------------ Data load ------------------

// ----------------- UI widgets -----------------

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
                  colors: [color, color.withOpacity(.85)],
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
              child: Icon(icon, size: 22, color: Colors.white),
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

  const _RingProgress({
    required this.size,
    required this.percent,
    this.stroke = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(percent: percent.clamp(0.0, 1.0), stroke: stroke),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                ).createShader(b),
                child: Text(
                  '${(percent * 100).round()}%',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: .95,
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
                  letterSpacing: .5,
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
  _RingPainter({required this.percent, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEEEEEE)
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF6F00), Color(0xFFFF8F00), Color(0xFFFFA726)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bg);

    final start = -90 * (3.1415926535 / 180);
    final sweep = 2 * 3.1415926535 * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fg,
    );
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
                          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                        )
                      : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? null
                      : Border.all(color: const Color(0xFFE0E0E0), width: 2),
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
                    colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
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
                child: const Icon(Icons.flag, color: Colors.white, size: 20),
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
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (calendarTitle != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Text(
                            calendarTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF757575),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (onRefresh != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
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
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6F00)),
                ),
              ),
            )
          else if (error != null)
            Container(
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
                          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
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

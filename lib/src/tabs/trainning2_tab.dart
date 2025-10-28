// lib/src/tabs/trainning2_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../trainingtask_page.dart';
import '../training_repo.dart';

class Trainning2Tab extends StatefulWidget {
  const Trainning2Tab({super.key});

  @override
  State<Trainning2Tab> createState() => _Trainning2TabState();
}

class _Trainning2TabState extends State<Trainning2Tab> {
  String _runningTarget = '-'; // เช่น "400 m × 4" หรือ "3 KM"
  String _timeTarget = '-'; // เช่น "1:30 / 3:50" หรือ "30 Min"
  String _runningType = '-'; // Rest | Interval | Long run | ...
  String? _currentProgramId;

  @override
  void initState() {
    super.initState();
    _loadProgramId();
  }

  Future<void> _loadProgramId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final programIdList = await TrainingRepo.fetchCurrentProgramId(user.uid);
    setState(() => _currentProgramId = programIdList?.first);

    if (_currentProgramId != null) {
      await _loadTodayPlan();
    }
  }

  Future<void> _loadTodayPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

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
      if (snap.exists) {
        final data = snap.data()!;
        setState(() {
          _runningTarget = (data['distance'] as String?) ?? 'N/A';
          _timeTarget = (data['time'] as String?) ?? 'N/A';
          _runningType = (data['type'] as String?) ?? 'Rest';
        });
      } else {
        setState(() {
          _runningTarget = 'N/A';
          _timeTarget = 'N/A';
          _runningType = 'No Plan';
        });
      }
    } catch (_) {
      setState(() {
        _runningTarget = 'Error';
        _timeTarget = 'Error';
        _runningType = 'Error';
      });
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _todayDocStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return null;

    final todayId = DateFormat('dd-MM-yyyy').format(DateTime.now());
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(_currentProgramId!)
        .collection('Training')
        .doc(todayId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRestDay = _runningType.toLowerCase() == 'rest';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'แผนการฝึกวันนี้',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: const Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year + 543}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF757575),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _planCard(theme, isRestDay: isRestDay),
                        const SizedBox(height: 16),
                        _dateTimeCard(context),
                        const SizedBox(height: 16),
                        _summaryTodayCard(theme),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6F00).withOpacity(.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isRestDay) {
                        showDialog(
                          context: context,
                          builder: (_) => const AlertDialog(
                            title: Text('วันนี้เป็นวันพัก'),
                            content: Text(
                              'ตามแผนในปฏิทิน วันนี้เป็นวันพัก (Rest day) — ยังไม่ควรฝึกครับ',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScreenTwo()),
                      );
                    },
                    icon: Icon(
                      isRestDay ? Icons.bedtime : Icons.play_arrow,
                      size: 28,
                    ),
                    label: Text(
                      isRestDay ? 'วันนี้เป็นวันพัก' : 'เริ่มฝึกเลย',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(ThemeData theme, {required bool isRestDay}) {
    final parsed = _parseIntervalSpec(_runningTarget, _timeTarget);
    final isInterval = _runningType.toLowerCase() == 'interval';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
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
                child: const Icon(
                  Icons.directions_run,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Today Plan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF212121),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isRestDay
                      ? const Color(0xFFEF4444).withOpacity(.12)
                      : (isInterval
                            ? const Color(0xFF0EA5E9).withOpacity(.12)
                            : const Color(0xFF10B981).withOpacity(.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _runningType,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isRestDay
                        ? const Color(0xFFEF4444)
                        : (isInterval
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFF10B981)),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statCell(
                  theme,
                  headline: 'ระยะทาง',
                  value: _runningTarget,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCell(theme, headline: 'เวลา', value: _timeTarget),
              ),
            ],
          ),
          if (isInterval && parsed != null) ...[
            const SizedBox(height: 12),
            Text(
              'Interval: ${parsed.segmentLabel} × ${parsed.reps}${parsed.workRestLabel.isNotEmpty ? "  |  ${parsed.workRestLabel}" : ""}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF616161),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateTimeCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          blurRadius: 10,
          offset: const Offset(0, 2),
          color: Colors.black.withOpacity(.05),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _InfoItem(
          icon: Icons.calendar_today,
          label: 'วันที่',
          value: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        Container(width: 1, height: 36, color: const Color(0xFFE0E0E0)),
        _InfoItem(
          icon: Icons.access_time,
          label: 'เวลา',
          value: TimeOfDay.now().format(context),
        ),
      ],
    ),
  );

  Widget _summaryTodayCard(ThemeData theme) {
    final stream = _todayDocStream();
    if (stream == null)
      return _emptyCard(
        theme,
        'ยังไม่ได้เข้าสู่ระบบ หรือยังไม่มีโปรแกรมที่ใช้งานอยู่',
      );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return _loadingCard();
        if (!snap.hasData || !snap.data!.exists)
          return _emptyCard(theme, 'ยังไม่มีบันทึกการฝึกวันนี้');

        final data = snap.data!.data() ?? {};
        final progress = ((data['progress_bar_percent'] ?? 0) as num)
            .clamp(0, 100)
            .toDouble();
        final distanceKm = ((data['distance_km'] ?? 0) as num).toDouble();
        final duration = (data['duration_display'] ?? '-') as String;
        final avgSpeed =
            (data['average_speed_kph'] ?? data['average_speed_kpn'] ?? '0')
                .toString();
        final activity = (data['activity'] ?? '-').toString();
        final typeLower = (data['type'] ?? '').toString().toLowerCase();

        // Interval section: ดึง laps + segment_m
        Widget? intervalSection;
        if (typeLower == 'interval' && (data['interval'] is Map)) {
          // ✅ แปลง map ให้เป็น <String, dynamic> เสมอ
          final interval = Map<String, dynamic>.from(data['interval'] as Map);

          // ✅ อ่านค่าแบบปลอดภัย
          final repsDone = (interval['reps_done'] as num?)?.toInt() ?? 0;
          final lapProg = (interval['lap_progress'] as num?)?.toDouble() ?? 0.0;
          final reps = (interval['total_reps'] as num?)?.toInt() ?? 0;
          final segM = (interval['segment_m'] as num?)?.toDouble() ?? 0.0;

          final List<double> laps =
              (interval['laps'] as List?)
                  ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                  .toList() ??
              const <double>[];

          intervalSection = _IntervalLaps(
            reps: reps,
            labelPerLap: segM > 0 ? '${segM.toStringAsFixed(0)} M' : '',
            lapsDone: repsDone,
            currentLapProgress: lapProg,
            lapMeters: laps,
            segmentMeters: segM,
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 3),
                color: Colors.black.withOpacity(.06),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.timeline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ผลการฝึกวันนี้',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF212121),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (progress / 100.0).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: const Color(0xFFECECEC),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${progress.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCell(
                      theme,
                      headline: 'ระยะทาง (km)',
                      value: distanceKm.toStringAsFixed(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCell(theme, headline: 'เวลา', value: duration),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _statCell(
                      theme,
                      headline: 'ความเร็วเฉลี่ย (km/h)',
                      value: avgSpeed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCell(
                      theme,
                      headline: 'กิจกรรม',
                      value: activity,
                    ),
                  ),
                ],
              ),
              if (intervalSection != null) ...[
                const SizedBox(height: 16),
                intervalSection,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _emptyCard(ThemeData theme, String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF9E9E9E)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF616161),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _loadingCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(Color(0xFFFF6F00)),
        ),
      ),
    ),
  );

  Widget _statCell(
    ThemeData theme, {
    required String headline,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6F00).withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6F00).withOpacity(.15)),
      ),
      child: Column(
        children: [
          Text(
            headline,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF757575),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF212121),
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
    );
  }

  _IntervalSpec? _parseIntervalSpec(String? distance, String? time) {
    if (distance == null) return null;
    final re = RegExp(
      r'(\d+(?:\.\d+)?)\s*(km|m)\s*[x×]\s*(\d+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(distance.trim());
    if (m == null) return null;
    final seg = m.group(1)!;
    final unit = m.group(2)!.toLowerCase();
    final reps = int.tryParse(m.group(3)!) ?? 0;

    String workRest = '';
    if (time != null && time.contains('/')) workRest = time;

    return _IntervalSpec(
      reps: reps,
      segmentLabel: '$seg ${unit.toUpperCase()}',
      workRestLabel: workRest,
    );
  }
}

// ---------- Widgets/Models ----------

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const Icon(Icons.calendar_today, size: 24, color: Color(0xFFFF6F00)),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFF757575),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF212121),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _IntervalSpec {
  final int reps;
  final String segmentLabel;
  final String workRestLabel;
  _IntervalSpec({
    required this.reps,
    required this.segmentLabel,
    required this.workRestLabel,
  });
}

class _IntervalLaps extends StatelessWidget {
  final int reps;
  final String labelPerLap;
  final int lapsDone;
  final double currentLapProgress;
  final List<double>? lapMeters; // ระยะจริงที่ทำได้แต่ละ Lap (เมตร)
  final double? segmentMeters; // เป้าต่อ Lap (เมตร)

  const _IntervalLaps({
    required this.reps,
    required this.labelPerLap,
    required this.lapsDone,
    required this.currentLapProgress,
    this.lapMeters,
    this.segmentMeters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percents = List<double>.generate(reps, (i) {
      if (i < lapsDone) return 1.0;
      if (i == lapsDone) return currentLapProgress.clamp(0.0, 1.0);
      return 0.0;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interval Laps • $labelPerLap × $reps',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(reps, (i) {
            final p = i < percents.length ? percents[i] : 0.0;
            final doneMeters = (lapMeters != null && i < lapMeters!.length)
                ? lapMeters![i]
                : 0.0;
            final seg = (segmentMeters ?? 0) > 0
                ? '/ ${segmentMeters!.toStringAsFixed(0)} m'
                : '';
            final label = (segmentMeters ?? 0) > 0
                ? 'Lap ${i + 1}  •  ${doneMeters.toStringAsFixed(0)} m $seg'
                : 'Lap ${i + 1}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LapBar(index: i + 1, percent: p, overlayLabel: label),
            );
          }),
        ),
      ],
    );
  }
}

class _LapBar extends StatelessWidget {
  final int index;
  final double percent;
  final String overlayLabel;
  const _LapBar({
    required this.index,
    required this.percent,
    required this.overlayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFECECEC);
    final gradient = const LinearGradient(
      colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
    );

    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: percent.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6F00).withOpacity(.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                overlayLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

  /// ====== เพิ่ม: เปิดฟอร์มเพิ่มข้อมูลเอง ======
  Future<void> _openManualEntrySheet() async {
    if (_currentProgramId == null) return;
    final spec = _parseIntervalSpec(
      _runningTarget,
      _timeTarget,
    ); // ถ้าวันนี้เป็น interval จะได้ reps/segment ไว้ใช้สร้างช่อง Lap

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ManualEntrySheet(
        type: _runningType,
        runningTargetText: _runningTarget,
        timeTargetText: _timeTarget,
        intervalSpec: spec,
      ),
    );

    if (result == null) return;

    // เขียนลง Firestore ให้รูปแบบตรงกับของระบบอัตโนมัติ
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final todayId = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(_currentProgramId!)
        .collection('Training')
        .doc(todayId);

    try {
      await ref.set(result, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลแบบกรอกเองเรียบร้อย')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
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

                /// ปุ่มหลัก “เริ่มฝึกเลย”
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

                const SizedBox(height: 10),

                /// ====== ปุ่มใหม่: เพิ่มข้อมูลเอง ======
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _openManualEntrySheet,
                    icon: const Icon(Icons.edit_note, color: Color(0xFFFF6F00)),
                    label: Text(
                      'เพิ่มข้อมูลเอง',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF6F00),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFFF6F00),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: Colors.white,
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
          final interval = Map<String, dynamic>.from(data['interval'] as Map);

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
      segmentMeters: unit == 'km'
          ? (double.parse(seg) * 1000.0)
          : double.parse(seg),
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
        Icon(
          icon,
          size: 24,
          color: const Color(0xFFFF6F00),
        ), // ← ใช้ icon ที่รับมา
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
  final double segmentMeters;
  _IntervalSpec({
    required this.reps,
    required this.segmentLabel,
    required this.workRestLabel,
    required this.segmentMeters,
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

/// ======== Bottom Sheet: แบบฟอร์มเพิ่มข้อมูลเอง (Styled) =========
class _ManualEntrySheet extends StatefulWidget {
  final String type; // Rest | Interval | Long run | Recovery | Tempo ...
  final String runningTargetText; // เช่น "400 m × 4" หรือ "3 KM"
  final String timeTargetText; // เช่น "1:30 / 3:50" หรือ "30 Min"
  final _IntervalSpec? intervalSpec;

  const _ManualEntrySheet({
    required this.type,
    required this.runningTargetText,
    required this.timeTargetText,
    required this.intervalSpec,
  });

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();

  // ช่องที่ใช้ร่วมกัน
  final _distanceKmCtrl = TextEditingController(); // ใช้กับ non-interval
  final _durationMinCtrl = TextEditingController(); // นาที
  final _durationSecCtrl = TextEditingController(); // วินาที
  final _avgSpeedCtrl = TextEditingController(); // ไม่บังคับ ให้ระบบคำนวณได้

  // สำหรับ Interval: ช่อง Lap ตามแผน
  late final List<TextEditingController> _lapCtrls;

  @override
  void initState() {
    super.initState();
    final reps = widget.intervalSpec?.reps ?? 0;
    _lapCtrls = List.generate(reps, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _distanceKmCtrl.dispose();
    _durationMinCtrl.dispose();
    _durationSecCtrl.dispose();
    _avgSpeedCtrl.dispose();
    for (final c in _lapCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInterval = widget.type.toLowerCase() == 'interval';
    final reps = widget.intervalSpec?.reps ?? 0;
    final segLabel = widget.intervalSpec?.segmentLabel ?? '';

    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              blurRadius: 30,
              color: Color(0x33000000),
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // grabber
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EAF0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
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
                              color: Color(0x33FF6F00),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_note,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เพิ่มข้อมูลการฝึกเอง',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _ChipTag(
                                  icon: Icons.category,
                                  label: widget.type,
                                ),
                                if (widget.runningTargetText.isNotEmpty)
                                  _ChipTag(
                                    icon: Icons.flag,
                                    label: widget.runningTargetText,
                                  ),
                                if (widget.timeTargetText.isNotEmpty)
                                  _ChipTag(
                                    icon: Icons.timer,
                                    label: widget.timeTargetText,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const _Gap(16),
                  const Divider(height: 1, color: Color(0xFFEFEFEF)),
                  const _Gap(10),

                  // Section: สรุปทั่วไป
                  const _SectionTitle(
                    icon: Icons.info_outline,
                    title: 'สรุปทั่วไป',
                  ),
                  const _Gap(
                    10,
                  ), // ← เพิ่มบรรทัดนี้เพื่อให้ระยะเท่าหัวข้อ "บันทึก Lap"

                  if (!isInterval) ...[
                    _NumField(
                      controller: _distanceKmCtrl,
                      label: 'ระยะทางรวม (กม.)',
                      hint: 'เช่น 3.20',
                      prefix: const Text(
                        'km',
                        style: TextStyle(color: Color(0xFF9AA3AF)),
                      ),
                      suffixGap: 10,
                    ),
                    const _Gap(12), // เดิม 10 (ขยับให้โปร่งขึ้นนิด)
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: _NumField(
                          controller: _durationMinCtrl,
                          label: 'เวลา (นาที)',
                          hint: 'เช่น 25',
                          prefixIcon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumField(
                          controller: _durationSecCtrl,
                          label: 'เวลา (วินาที)',
                          hint: 'เช่น 30',
                          prefixIcon: Icons.timelapse,
                        ),
                      ),
                    ],
                  ),
                  const _Gap(12), // เดิม 10

                  _NumField(
                    controller: _avgSpeedCtrl,
                    label: 'ความเร็วเฉลี่ย (กม./ชม.) (ไม่บังคับ)',
                    hint: 'ปล่อยว่างให้ระบบคำนวณได้',
                    prefixIcon: Icons.speed,
                  ),

                  if (isInterval) ...[
                    const _Gap(18),
                    const _SectionTitle(
                      icon: Icons.directions_run,
                      title: 'บันทึก Lap',
                    ),
                    Text(
                      'ตามแผน: $segLabel × $reps',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const _Gap(10),

                    // Laps: จัด layout ให้สวยและอ่านง่าย (2 คอลัมน์ถ้าพื้นที่พอ)
                    LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth >= 380;
                        final itemW = isWide
                            ? (c.maxWidth - 10) / 2
                            : c.maxWidth;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(reps, (i) {
                            return SizedBox(
                              width: itemW,
                              child: _NumField(
                                controller: _lapCtrls[i],
                                label: 'Lap ${i + 1} (เมตร)',
                                hint:
                                    (widget.intervalSpec?.segmentMeters
                                        .toStringAsFixed(0) ??
                                    '400'),
                                prefixIcon: Icons.flag_circle_outlined,
                                // suffix: const Text(
                                //   'm',
                                //   style: TextStyle(color: Color(0xFF9AA3AF)),
                                // ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],

                  const _Gap(20),
                  // Save button (sticky look & feel)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3310B981),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if ((_durationMinCtrl.text.trim().isEmpty) &&
                            (_durationSecCtrl.text.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('กรอกเวลาอย่างน้อย 1 ช่อง'),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(_buildFirestoreBody());
                      },
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 3.0),
                        child: Text(
                          'บันทึก',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _buildFirestoreBody() {
    // ----- helpers (ประกาศไว้บนสุดของเมธอด เพื่อใช้ได้ทันที) -----
    double _parseTargetDistanceKmNonInterval(String text) {
      final re = RegExp(r'(\d+(?:\.\d+)?)\s*(km|กม)\b', caseSensitive: false);
      final m = re.firstMatch(text.trim());
      if (m == null) return 0.0;
      return double.tryParse(m.group(1)!) ?? 0.0;
    }

    int _parseTargetTimeMinNonInterval(String text) {
      final t = text.trim();

      // รูปแบบ mm:ss หรือ hh:mm:ss
      final colon = RegExp(r'^(\d{1,2})(?::(\d{2}))(?::(\d{2}))?$');
      final mc = colon.firstMatch(t);
      if (mc != null) {
        final h = int.tryParse(mc.group(1)!) ?? 0;
        final m = int.tryParse(mc.group(2)!) ?? 0;
        final s = int.tryParse(mc.group(3) ?? '0') ?? 0;
        return (h * 60) + m + (s >= 30 ? 1 : 0); // ปัดนาทีอย่างง่าย
      }

      // "30 นาที" / "30 min" / "30 mins"
      final word = RegExp(
        r'(\d+)\s*(นาที|minute|min|mins)',
        caseSensitive: false,
      );
      final mw = word.firstMatch(t);
      if (mw != null) return int.tryParse(mw.group(1)!) ?? 0;

      // ถ้าเป็น interval มักเป็น "work/rest" เช่น "1:30 / 3:50" — ไม่ใช้
      return 0;
    }

    // ---------------------------------------------------------------
    List<double> _weightsForTypeManual(
      String type,
      double targetKm,
      int targetMin,
    ) {
      final t = type.toLowerCase();

      // Tempo = เหมือน Recovery/Long/Easy → ระยะล้วน
      if (t.contains('recovery') ||
          t.contains('easy') ||
          t.contains('long') ||
          t.contains('tempo')) {
        return [0.0, 1.0]; // [เวลา, ระยะ]
      }

      final hasTime = targetMin > 0;
      final hasDist = targetKm > 0;
      if (hasTime && hasDist) return [0.5, 0.5];
      if (hasTime) return [1.0, 0.0];
      if (hasDist) return [0.0, 1.0];
      return [0.0, 0.0];
    }

    final mins = int.tryParse(_durationMinCtrl.text.trim()) ?? 0;
    final secs = int.tryParse(_durationSecCtrl.text.trim()) ?? 0;
    final totalSecs = (mins * 60) + secs;

    String two(int n) => n.toString().padLeft(2, '0');
    final durationStr = '00:${two(mins)}:${two(secs)}';

    final now = Timestamp.now();
    final base = <String, dynamic>{
      'date': now,
      'type': widget.type,
      'distance': widget.runningTargetText,
      'time': widget.timeTargetText,
      'activity': 'manual',
      'duration_s': totalSecs,
      'duration_display': durationStr,
      'updatedAt': now,
      'source': 'manual',
    };

    // ---------- NON-INTERVAL ----------
    final isInterval = widget.type.toLowerCase() == 'interval';
    if (!isInterval) {
      final distanceKm = double.tryParse(_distanceKmCtrl.text.trim()) ?? 0.0;
      final avg = _avgSpeedFromInputs(distanceKm, totalSecs);

      final targetKm = _parseTargetDistanceKmNonInterval(
        widget.runningTargetText,
      );
      final targetMin = _parseTargetTimeMinNonInterval(widget.timeTargetText);

      // ใช้น้ำหนักตามชนิดการวิ่ง (Tempo/Recovery/Long/Easy = ระยะล้วน)
      final weights = _weightsForTypeManual(widget.type, targetKm, targetMin);
      final wTime = weights[0], wDist = weights[1];

      double pTime = 0.0, pDist = 0.0;
      if (targetMin > 0) pTime = totalSecs / (targetMin * 60);
      if (targetKm > 0) pDist = distanceKm / targetKm;

      final progress =
          (pTime.clamp(0, 1) * wTime) + (pDist.clamp(0, 1) * wDist);

      base.addAll({
        'distance_km': distanceKm,
        'average_speed_kph': avg.toStringAsFixed(2),
        'progress_bar_percent': (progress * 100).round().clamp(0, 100),
      });
      return base;
    }

    /// ---------- INTERVAL ----------
    final segM = widget.intervalSpec?.segmentMeters ?? 0.0;
    final reps = widget.intervalSpec?.reps ?? 0;

    final lapsMeters = List<double>.generate(reps, (i) {
      final v = double.tryParse(_lapCtrls[i].text.trim()) ?? 0.0;
      return segM > 0 ? v.clamp(0.0, segM) : v;
    });

    final repsDone = segM > 0
        ? lapsMeters.where((m) => m >= segM).length
        : lapsMeters.length;

    final currentLapIndex = segM > 0 ? repsDone : 0;
    final lapProgress = (segM > 0 && currentLapIndex < reps)
        ? (lapsMeters[currentLapIndex] / segM).clamp(0.0, 1.0)
        : 0.0;

    final sumMeters = lapsMeters.fold<double>(0.0, (a, b) => a + b);
    final totalKm = sumMeters / 1000.0;
    final avg = _avgSpeedFromInputs(totalKm, totalSecs);

    // สูตรเดียวกับ runtime: (จำนวน lap ที่จบ + ความคืบหน้า lap ปัจจุบัน) / จำนวน lap ทั้งหมด
    double progress = 0.0;
    if (reps > 0) {
      progress = ((repsDone + lapProgress) / reps).clamp(0.0, 1.0);
    }

    base.addAll({
      'distance_km': totalKm,
      'average_speed_kph': avg.toStringAsFixed(2),
      'progress_bar_percent': (progress * 100).round().clamp(0, 100),
      'interval': {
        'segment_m': segM,
        'total_reps': reps,
        'laps': lapsMeters,
        'reps_done': repsDone,
        'lap_progress': lapProgress,
        'mode': 'run',
        'rest_left_s': 0,
        'finished': repsDone >= reps,
        'updatedAt': now,
      },
    });

    return base;
  }

  double _avgSpeedFromInputs(double distanceKm, int totalSecs) {
    final manualAvg = double.tryParse(_avgSpeedCtrl.text.trim());
    if (manualAvg != null && manualAvg > 0) return manualAvg;
    if (distanceKm > 0 && totalSecs > 0) {
      return distanceKm / (totalSecs / 3600.0);
    }
    return 0.0;
  }
}

/// ------------ Reusable UI helpers ------------
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFFF6F00), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _ChipTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ChipTag({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  final double h;
  const _Gap(this.h);
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final double suffixGap;

  const _NumField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.suffixGap = 4,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    );
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFFF6F00), width: 1.6),
    );

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: const Color(0xFF9AA3AF))
            : null,
        prefix: prefix != null
            ? Padding(
                padding: const EdgeInsets.only(left: 8, right: 6),
                child: prefix,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix != null
            ? Padding(
                padding: EdgeInsets.only(right: suffixGap),
                child: suffix,
              )
            : null,
        border: border,
        enabledBorder: border,
        focusedBorder: focused,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

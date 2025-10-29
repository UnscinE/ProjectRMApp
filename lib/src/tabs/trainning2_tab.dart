// lib/src/tabs/trainning2_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ⬇️ อยู่คนละโฟลเดอร์ ต้องอ้างแบบ relative ออกไปหนึ่งชั้น
import '../trainingtask_page.dart';
import '../training_repo.dart';

class Trainning2Tab extends StatefulWidget {
  const Trainning2Tab({super.key});

  @override
  State<Trainning2Tab> createState() => _Trainning2TabState();
}

class _Trainning2TabState extends State<Trainning2Tab> {
  String _runningTarget = '-';
  String _timeTarget = '-';
  String _runningType = '-';
  String? _currentProgramId;

  @override
  void initState() {
    super.initState();
    _loadProgramId();
  }

  Future<void> _loadProgramId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ต้องมีเมธอดนี้ใน training_repo.dart
    final programIdList = await TrainingRepo.fetchCurrentProgramId(user.uid);
    setState(() => _currentProgramId = programIdList?.first);

    if (_currentProgramId != null) {
      await _loadTodayPlan();
    }
  }

  Future<void> _loadTodayPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    // ให้ตรงกับหน้าฝึก (ScreenTwo) ที่บันทึกเอกสารเป็น dd-MM-yyyy
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

  /// สร้างสตรีมเอกสารบันทึก "วันนี้" เพื่อแสดงผลแบบ realtime
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
                // ---------- ส่วนที่สโครลได้ ----------
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // หัวข้อ + วันที่
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

                        // ---------- Card: Today Plan ----------
                        _planCard(theme),

                        const SizedBox(height: 16),

                        // ---------- Card: วันที่/เวลา ----------
                        _dateTimeCard(context),

                        const SizedBox(height: 16),

                        // ---------- Card: ผลการฝึกวันนี้ (Realtime) ----------
                        _summaryTodayCard(theme),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ---------- ปุ่มด้านล่าง (ไม่สโครล) ----------
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScreenTwo()),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      'เริ่มฝึกเลย',
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

  // ---------------- UI blocks ----------------

  Widget _planCard(ThemeData theme) => Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _runningType,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF10B981),
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
      ],
    ),
  );

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
    if (stream == null) {
      return _emptyCard(
        theme,
        'ยังไม่ได้เข้าสู่ระบบ หรือยังไม่มีโปรแกรมที่ใช้งานอยู่',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        if (!snap.hasData || !snap.data!.exists) {
          return _emptyCard(theme, 'ยังไม่มีบันทึกการฝึกวันนี้');
        }

        final data = snap.data!.data() ?? {};
        final progress = ((data['progress_bar_percent'] ?? 0) as num)
            .clamp(0, 100)
            .toDouble();
        final distanceKm = ((data['distance_km'] ?? 0) as num).toDouble();
        final duration = (data['duration_display'] ?? '-') as String;
        final avgSpeed = (data['average_speed_kph'] ?? '0').toString();
        final activity = (data['activity'] ?? '-').toString();

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
}

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
        Icon(icon, size: 24, color: const Color(0xFFFF6F00)),
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

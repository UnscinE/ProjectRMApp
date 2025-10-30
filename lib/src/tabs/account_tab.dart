import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../program_details_page.dart';
import '../training_repo.dart';
import 'all_programs_page.dart';

enum DistanceUnit { km, mi }

enum Sex { male, female, other }

// ===== Orange palette (แต่งเฉพาะสี/สไตล์) =====
const _orange1 = Color(0xFFFF6F00);
const _orange2 = Color(0xFFFF8F00);
const _bgTop = Color(0xFFFAFAFA);
const _bgBot = Color(0xFFF5F5F5);
const _textMain = Color(0xFF212121);
const _textMuted = Color(0xFF616161);
const _line = Color(0xFFECECEC);

class AccountTab extends StatefulWidget {
  final String email;
  final String? displayName;
  final VoidCallback? onSignOut;
  final Future<void> Function()? onDeleteAccount;
  final Future<void> Function()? onExportData;
  final VoidCallback? onManageGoals;
  final VoidCallback? onViewHistory;

  const AccountTab({
    super.key,
    required this.email,
    this.displayName,
    this.onSignOut,
    this.onDeleteAccount,
    this.onExportData,
    this.onManageGoals,
    this.onViewHistory,
  });

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _auth = FirebaseAuth.instance;

  // สถานะแก้ไขชั่วคราว (จะ push เข้า Firestore เมื่อกดบันทึก)
  double? _weightKg;
  double? _heightCm;
  int? _age;
  Sex _sex = Sex.male;
  String? _nickname;

  // helpers
  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'น้ำหนักต่ำกว่าเกณฑ์';
    if (bmi < 23) return 'สมส่วน';
    if (bmi < 25) return 'ท้วม';
    if (bmi < 30) return 'อ้วนระดับ 1';
    return 'อ้วนระดับ 2';
  }

  double? _calcBmi(double? w, double? h) {
    if (w == null || h == null || h == 0) return null;
    final m = h / 100.0;
    return w / (m * m);
  }

  Future<void> _saveToFirestore() async {
    final uid = _auth.currentUser!.uid;
    final bmi = _calcBmi(_weightKg, _heightCm);
    await TrainingRepo.updateProfile(
      uid,
      displayName: _nickname,
      weightKg: _weightKg,
      heightCm: _heightCm,
      age: _age,
      sex: _sex.name,
      bmi: bmi,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลแล้ว')));
  }

  Future<double?> _promptDouble(
    String title,
    String hint, {
    double? initial,
    String? suffix,
  }) async {
    final c = TextEditingController(
      text: initial == null ? '' : initial.toString(),
    );
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint, suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<int?> _promptInt(
    String title,
    String hint, {
    int? initial,
    String? suffix,
  }) async {
    final c = TextEditingController(
      text: initial == null ? '' : initial.toString(),
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint, suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(c.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบ'));
    }
    final uid = _auth.currentUser!.uid;

    // ฟังการเปลี่ยนแปลง users/{uid} แบบ realtime
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBot],
        ),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: TrainingRepo.userDocStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? {};

          // sync ค่าเริ่มต้นครั้งแรกเพื่อแสดงบนจอ (แต่ยังไม่บันทึก)
          _nickname ??=
              (data['displayName'] as String?) ??
              widget.displayName ??
              widget.email;
          _weightKg ??= (data['weight_kg'] as num?)?.toDouble();
          _heightCm ??= (data['height_cm'] as num?)?.toDouble();
          _age ??= (data['age'] as num?)?.toInt();
          _sex = switch (data['sex']) {
            'female' => Sex.female,
            'other' => Sex.other,
            'male' => Sex.male,
            _ => _sex,
          };

          final bmi = _calcBmi(_weightKg, _heightCm);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // โปรไฟล์หัวการ์ด (ย่อ)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: _line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่อ/อีเมล
                      Text(
                        _nickname ?? widget.email,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _textMain,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.email,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _textMuted),
                      ),
                      const SizedBox(height: 10),
                      // ปุ่มแก้ชื่อ (Outlined โทนส้ม)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('แก้ไขชื่อที่แสดง'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _orange1,
                          side: const BorderSide(color: _orange1, width: 1.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () async {
                          final controller = TextEditingController(
                            text: _nickname ?? '',
                          );
                          final res = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('แก้ไขชื่อที่แสดง'),
                              content: TextField(controller: controller),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('ยกเลิก'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(
                                    ctx,
                                    controller.text.trim(),
                                  ),
                                  child: const Text('บันทึก'),
                                ),
                              ],
                            ),
                          );
                          if (res != null && res.isNotEmpty) {
                            setState(() => _nickname = res);
                            await _saveToFirestore();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ข้อมูลร่างกาย
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: _line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หัวข้อเซคชัน
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_orange1, _orange2],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange1.withOpacity(.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),

                          const SizedBox(width: 10),
                          Text(
                            'ข้อมูลร่างกาย',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _textMain,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.monitor_weight,
                          color: _orange1,
                        ),
                        title: const Text('น้ำหนัก'),
                        subtitle: Text(
                          _weightKg == null
                              ? 'ยังไม่ได้ระบุ'
                              : '${_weightKg!.toStringAsFixed(1)} กก.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final v = await _promptDouble(
                            'น้ำหนัก (กก.)',
                            'เช่น 65.0',
                            initial: _weightKg,
                            suffix: 'กก.',
                          );
                          if (v != null && v > 0 && v < 500) {
                            setState(() => _weightKg = v);
                            await _saveToFirestore();
                          }
                        },
                      ),

                      const Divider(color: _line, height: 8),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.height, color: _orange1),
                        title: const Text('ส่วนสูง'),
                        subtitle: Text(
                          _heightCm == null
                              ? 'ยังไม่ได้ระบุ'
                              : '${_heightCm!.toStringAsFixed(1)} ซม.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final v = await _promptDouble(
                            'ส่วนสูง (ซม.)',
                            'เช่น 175',
                            initial: _heightCm,
                            suffix: 'ซม.',
                          );
                          if (v != null && v > 0 && v < 300) {
                            setState(() => _heightCm = v);
                            await _saveToFirestore();
                          }
                        },
                      ),
                      const Divider(color: _line, height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.wc, color: _orange1),
                              title: const Text('เพศ'),
                              trailing: DropdownButton<Sex>(
                                value: _sex,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(
                                    value: Sex.male,
                                    child: Text('ชาย'),
                                  ),
                                  DropdownMenuItem(
                                    value: Sex.female,
                                    child: Text('หญิง'),
                                  ),
                                  DropdownMenuItem(
                                    value: Sex.other,
                                    child: Text('อื่น ๆ'),
                                  ),
                                ],
                                onChanged: (v) async {
                                  if (v == null) return;
                                  setState(() => _sex = v);
                                  await _saveToFirestore();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.cake_outlined,
                                color: _orange1,
                              ),
                              title: const Text('อายุ'),
                              subtitle: Text(
                                _age == null ? 'ยังไม่ได้ระบุ' : '$_age ปี',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final v = await _promptInt(
                                  'อายุ (ปี)',
                                  'เช่น 22',
                                  initial: _age,
                                  suffix: 'ปี',
                                );
                                if (v != null && v > 0 && v < 120) {
                                  setState(() => _age = v);
                                  await _saveToFirestore();
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      if (bmi != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _orange1.withOpacity(.08),
                            border: Border.all(
                              color: _orange1.withOpacity(.18),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.insights,
                                size: 18,
                                color: _orange1,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'BMI: ${bmi.toStringAsFixed(1)} • ${_bmiLabel(bmi)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'หมายเหตุ: ใช้เพื่อประเมินภาพรวมเท่านั้น',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: _line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_orange1, _orange2],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange1.withOpacity(.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.history,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            'ประวัติการฝึก',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _textMain,
                                ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('Program')
                            .orderBy('createdAt', descending: true)
                            .limit(3)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('ไม่มีประวัติการฝึก'),
                            );
                          }

                          final programs = snapshot.data!.docs;

                          return Column(
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: programs.length,
                                itemBuilder: (context, index) {
                                  final program = programs[index];
                                  final programData =
                                      program.data() as Map<String, dynamic>;
                                  final programName =
                                      programData['targetKm'].toString() ??
                                      'โปรแกรม';
                                  final duration =
                                      programData['totalWeeks'].toString() ??
                                      'N/A';

                                  return FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .collection('Program')
                                        .doc(program.id)
                                        .collection('trainingTasks')
                                        .get(),
                                    builder: (context, taskSnapshot) {
                                      if (!taskSnapshot.hasData) {
                                        return const ListTile(
                                          title: Text('Loading...'),
                                        );
                                      }
                                      final tasks = taskSnapshot.data!.docs;
                                      final completedTasks = tasks.where((
                                        task,
                                      ) {
                                        final data =
                                            task.data() as Map<String, dynamic>;
                                        return (data['completed'] as bool?) ??
                                            false;
                                      }).length;
                                      final progress = tasks.isEmpty
                                          ? 0.0
                                          : completedTasks / tasks.length;

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.directions_run,
                                          color: _orange1,
                                        ),
                                        title: Text('$programName km'),
                                        subtitle: Text(
                                          '$duration สัปดาห์ • ${(progress * 100).toStringAsFixed(0)}% สำเร็จ',
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ProgramDetailsPage(
                                                    userId: uid,
                                                    program: program,
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              if (programs.length >= 3)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AllProgramsPage(userId: uid),
                                        ),
                                      );
                                    },
                                    child: const Text('ดูทั้งหมด'),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ปุ่มออกจากระบบ (ถ้ามี callback)
              if (widget.onSignOut != null)
                FilledButton.icon(
                  onPressed: widget.onSignOut!,
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกจากระบบ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange1,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
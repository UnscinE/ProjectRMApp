import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../training_repo.dart';

enum DistanceUnit { km, mi }
enum Sex { male, female, other }

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลแล้ว')));
  }

  Future<double?> _promptDouble(String title, String hint, {double? initial, String? suffix}) async {
    final c = TextEditingController(text: initial == null ? '' : initial.toString());
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () {
            final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
            Navigator.pop(ctx, v);
          }, child: const Text('บันทึก')),
        ],
      ),
    );
  }

  Future<int?> _promptInt(String title, String hint, {int? initial, String? suffix}) async {
    final c = TextEditingController(text: initial == null ? '' : initial.toString());
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () {
            final v = int.tryParse(c.text.trim());
            Navigator.pop(ctx, v);
          }, child: const Text('บันทึก')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    // ฟังการเปลี่ยนแปลง users/{uid} แบบ realtime
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: TrainingRepo.userDocStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data?.data() ?? {};

        // sync ค่าเริ่มต้นครั้งแรกเพื่อแสดงบนจอ (แต่ยังไม่บันทึก)
        _nickname ??= (data['displayName'] as String?) ?? widget.displayName ?? widget.email;
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nickname ?? widget.email, style: Theme.of(context).textTheme.titleMedium),
                    Text(widget.email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('แก้ไขชื่อที่แสดง'),
                      onPressed: () async {
                        final controller = TextEditingController(text: _nickname ?? '');
                        final res = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('แก้ไขชื่อที่แสดง'),
                            content: TextField(controller: controller),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('บันทึก')),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ข้อมูลร่างกาย', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),

                    ListTile(
                      leading: const Icon(Icons.monitor_weight),
                      title: const Text('น้ำหนัก'),
                      subtitle: Text(_weightKg == null ? 'ยังไม่ได้ระบุ' : '${_weightKg!.toStringAsFixed(1)} กก.'),
                      onTap: () async {
                        final v = await _promptDouble('น้ำหนัก (กก.)', 'เช่น 65.0', initial: _weightKg, suffix: 'กก.');
                        if (v != null && v > 0 && v < 500) { setState(() => _weightKg = v); await _saveToFirestore(); }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.height),
                      title: const Text('ส่วนสูง'),
                      subtitle: Text(_heightCm == null ? 'ยังไม่ได้ระบุ' : '${_heightCm!.toStringAsFixed(1)} ซม.'),
                      onTap: () async {
                        final v = await _promptDouble('ส่วนสูง (ซม.)', 'เช่น 175', initial: _heightCm, suffix: 'ซม.');
                        if (v != null && v > 0 && v < 300) { setState(() => _heightCm = v); await _saveToFirestore(); }
                      },
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.wc),
                            title: const Text('เพศ'),
                            trailing: DropdownButton<Sex>(
                              value: _sex,
                              items: const [
                                DropdownMenuItem(value: Sex.male, child: Text('ชาย')),
                                DropdownMenuItem(value: Sex.female, child: Text('หญิง')),
                                DropdownMenuItem(value: Sex.other, child: Text('อื่น ๆ')),
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
                            leading: const Icon(Icons.cake_outlined),
                            title: const Text('อายุ'),
                            subtitle: Text(_age == null ? 'ยังไม่ได้ระบุ' : '$_age ปี'),
                            onTap: () async {
                              final v = await _promptInt('อายุ (ปี)', 'เช่น 22', initial: _age, suffix: 'ปี');
                              if (v != null && v > 0 && v < 120) { setState(() => _age = v); await _saveToFirestore(); }
                            },
                          ),
                        ),
                      ],
                    ),

                    if (bmi != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.fitness_center, size: 18),
                        const SizedBox(width: 6),
                        Text('BMI: ${bmi.toStringAsFixed(1)} • ${_bmiLabel(bmi)}'),
                      ]),
                      Text('หมายเหตุ: ใช้เพื่อประเมินภาพรวมเท่านั้น',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                    ],
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
              ),
          ],
        );
      },
    );
  }
}

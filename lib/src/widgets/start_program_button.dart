import 'package:flutter/material.dart';
import '../widgets/calendar_helper.dart'; // ใช้ addStartProgramToCalendar ที่ helper

class StartProgramButton extends StatelessWidget {
  final int targetKm;
  final int trainingWeeks;

  const StartProgramButton({
    super.key,
    required this.targetKm,
    required this.trainingWeeks,
  });

  Future<void> _pickAndAdd(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'เลือกวันเริ่มโปรแกรม',
      confirmText: 'ตกลง',
      cancelText: 'ยกเลิก',
    );
    if (picked == null) return;

    final start = DateTime(picked.year, picked.month, picked.day, 8, 0);

    await addStartProgramToCalendar(
      startDate: start,
      trainingWeeks: trainingWeeks,
      targetKm: targetKm,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดปฏิทินเพื่อเพิ่มกำหนดการแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _pickAndAdd(context),
      icon: const Icon(Icons.event_available),
      label: const Text('ตั้งวันเริ่มในปฏิทิน'),
    );
  }
}

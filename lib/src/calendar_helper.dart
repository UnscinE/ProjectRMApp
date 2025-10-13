import 'dart:convert';
import 'dart:io';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// ========== 1) Single recurring event (ยังใช้ได้เหมือนเดิม) ==========
Future<void> addStartProgramToCalendar({
  required DateTime startDate,
  required int trainingWeeks,
  required int targetKm,
}) async {
  final title = 'เริ่มโปรแกรมวิ่ง $targetKm กม.';
  final desc  = 'โปรแกรมฝึกวิ่ง ${targetKm} กม. ระยะเวลา $trainingWeeks สัปดาห์';

  final endDate = startDate.add(const Duration(hours: 1));
  final recurEnd = startDate.add(Duration(days: 7 * (trainingWeeks - 1)));

  if (!kIsWeb) {
    final event = Event(
      title: title,
      description: desc,
      startDate: startDate,
      endDate: endDate,
      allDay: false,
      recurrence: Recurrence(
        frequency: Frequency.weekly,
        endDate: recurEnd,
      ),
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
      androidParams: const AndroidParams(emailInvites: []),
    );
    await Add2Calendar.addEvent2Cal(event);
    return;
  }

  String fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}00';
  }

  final dates = '${fmt(startDate)}/${fmt(endDate)}';
  final url =
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(title)}'
      '&details=${Uri.encodeComponent('$desc\\n(จะมีนัดหมายรายสัปดาห์)')}'
      '&dates=$dates';

  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

/// ========== 2) Export ตารางจริงทั้งโปรแกรมเป็นไฟล์ .ics ==========
Future<void> exportTrainingPlanToICS({
  required DateTime week1StartDate,     // วันที่ถือเป็น "วันจันทร์" ของสัปดาห์ที่ 1
  required int totalWeeks,              // เช่น 4
  required int targetKm,                // เช่น 5
  required List<List<Map<String, String>>> planByWeeks,
  int startHour = 8,                    // เริ่ม 08:00
}) async {
  // helper แปลงชื่อวัน -> index(1..7) ให้ตรงกับจันทร์..อาทิตย์
  int dayIndex(String day) {
    switch (day.toLowerCase()) {
      case 'mon': return 1;
      case 'tue': return 2;
      case 'wed': return 3;
      case 'thu': return 4;
      case 'fri': return 5;
      case 'sat': return 6;
      case 'sun': return 7;
      default: return 1;
    }
  }

  // parse นาทีจากข้อความ "21 Min" หรือ "1:30 / 3:50 Min/Set"
  int guessMinutes(String? timeText) {
    if (timeText == null || timeText.trim().isEmpty || timeText == '-') return 60;
    final t = timeText.toLowerCase();

    // case 1: "21 min"
    final reg1 = RegExp(r'(\d+)\s*min');
    final m1 = reg1.firstMatch(t);
    if (m1 != null) return int.tryParse(m1.group(1)!) ?? 60;

    // case 2: "1:30 / 3:50 min/set" -> เอาตัวหน้าสุด "1:30" เป็นเวลาต่อเซ็ต สมมติ 4 เซ็ต ~ 1:30*4? ต้องมีข้อมูลเพิ่ม
    // เพื่อความง่าย ใช้ 45 นาทีเป็นกลาง
    final reg2 = RegExp(r'(\d{1,2}):(\d{2})');
    final m2 = reg2.firstMatch(t);
    if (m2 != null) {
      final mm = int.tryParse(m2.group(1)!) ?? 0;
      final ss = int.tryParse(m2.group(2)!) ?? 0;
      final tot = mm + (ss >= 30 ? 1 : 0); // ปัดขึ้นแบบหยาบ
      return (tot <= 0 ? 45 : tot);
    }

    return 60;
  }

  String icsDate(DateTime dt) {
    // ใช้ "floating time" (ไม่ใส่ Z/TZID) ให้แอปรับไปตามโซนเครื่อง
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}00';
  }

  final buffer = StringBuffer();
  buffer.writeln('BEGIN:VCALENDAR');
  buffer.writeln('VERSION:2.0');
  buffer.writeln('PRODID:-//RMApp//TrainingPlan//TH');

  // วนทุกสัปดาห์/ทุกวันในแผน
  for (int w = 0; w < totalWeeks; w++) {
    final weekPlan = planByWeeks[w.clamp(0, planByWeeks.length - 1)];
    for (final row in weekPlan) {
      final day = row['day'] ?? 'Mon';
      final dist = row['dist'] ?? '-';
      final timeTxt = row['time'] ?? '-';
      final note = row['note'] ?? '';

      if (dist.trim() == '-' && note.toLowerCase() == 'rest') {
        // ข้ามวันพัก
        continue;
      }

      final startThis = week1StartDate
          .add(Duration(days: (dayIndex(day) - 1) + (7 * w)))
          .copyWith(hour: startHour, minute: 0, second: 0);

      final minutes = guessMinutes(timeTxt);
      final endThis = startThis.add(Duration(minutes: minutes));

      final uid = '${startThis.millisecondsSinceEpoch}-${w}-${day}';

      // SUMMARY
      final title = note.isEmpty || note.toLowerCase() == 'rest'
          ? 'ฝึกวิ่ง $dist'
          : '$note • $dist';

      // DESCRIPTION
      final descLines = <String>[];
      descLines.add('โปรแกรมวิ่ง $targetKm กม.');
      if (timeTxt.isNotEmpty && timeTxt != '-') descLines.add('เวลา: $timeTxt');
      if (note.isNotEmpty) descLines.add('หมายเหตุ: $note');
      final desc = descLines.join('\\n');

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:$uid');
      buffer.writeln('DTSTAMP:${icsDate(DateTime.now())}');
      buffer.writeln('DTSTART:${icsDate(startThis)}');
      buffer.writeln('DTEND:${icsDate(endThis)}');
      buffer.writeln('SUMMARY:${_escapeICS(title)}');
      buffer.writeln('DESCRIPTION:${_escapeICS(desc)}');
      buffer.writeln('END:VEVENT');
    }
  }

  buffer.writeln('END:VCALENDAR');

  final ics = buffer.toString();

  if (kIsWeb) {
    final dataUrl =
        'data:text/calendar;charset=utf-8,${Uri.encodeComponent(ics)}';
    await launchUrlString(dataUrl, mode: LaunchMode.externalApplication);
    return;
  }

  // mobile/desktop -> สร้างไฟล์ชั่วคราวแล้วเปิดด้วยแอปปฏิทิน
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/training_plan_${DateTime.now().millisecondsSinceEpoch}.ics');
  await file.writeAsString(ics, encoding: const Utf8Codec());
  await OpenFilex.open(file.path);
}

String _escapeICS(String input) {
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');
}

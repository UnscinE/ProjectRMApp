// lib/src/calendar_helper.dart
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';

/// ========== 1) สร้างนัดเริ่มโปรแกรม (มี recurring รายสัปดาห์) ==========
Future<void> addStartProgramToCalendar({
  required DateTime startDate,
  required int trainingWeeks,
  required int targetKm,
}) async {
  final title = 'เริ่มโปรแกรมวิ่ง $targetKm กม.';
  final desc = 'โปรแกรมฝึกวิ่ง ${targetKm} กม. ระยะเวลา $trainingWeeks สัปดาห์';
  final endDate = startDate.add(const Duration(hours: 1));
  final recurEnd = startDate.add(Duration(days: 7 * (trainingWeeks - 1)));

  if (!kIsWeb) {
    // มือถือ/เดสก์ท็อป: เพิ่มลงปฏิทินด้วย native sheet
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

  // เว็บ: เปิด Google Calendar (UTC format + RRULE weekly + COUNT)
  String fmtUtc(DateTime dt) {
    // รูปแบบที่ Google ต้องการ: YYYYMMDDTHHMMSSZ
    final d = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
  }

  final dates = '${fmtUtc(startDate)}/${fmtUtc(endDate)}';
  final rrule = 'RRULE:FREQ=WEEKLY;COUNT=$trainingWeeks';

  final url =
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(title)}'
      '&details=${Uri.encodeComponent('$desc\\n(นัดซ้ำรายสัปดาห์ จำนวน $trainingWeeks ครั้ง)')}'
      '&dates=$dates'
      '&recur=${Uri.encodeComponent(rrule)}';

  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

/// ========== 2) ส่งออกทั้งตารางฝึกเป็นไฟล์ .ics ==========
Future<void> exportTrainingPlanToICS({
  required DateTime week1StartDate,           // วันที่ถือเป็น "วันจันทร์" ของสัปดาห์ที่ 1
  required int totalWeeks,                    // เช่น 4
  required int targetKm,                      // เช่น 5
  required List<List<Map<String, String>>> planByWeeks,
  int startHour = 8,                          // เริ่ม 08:00
}) async {
  int dayIndex(String day) {
    switch (day.toLowerCase()) {
      case 'mon':
        return 1;
      case 'tue':
        return 2;
      case 'wed':
        return 3;
      case 'thu':
        return 4;
      case 'fri':
        return 5;
      case 'sat':
        return 6;
      case 'sun':
        return 7;
      default:
        return 1;
    }
  }

  // เดาประมาณเวลาฝึกจากข้อความ
  int guessMinutes(String? timeText) {
    if (timeText == null || timeText.trim().isEmpty || timeText == '-') return 60;
    final t = timeText.toLowerCase();

    // "21 min"
    final reg1 = RegExp(r'(\d+)\s*min');
    final m1 = reg1.firstMatch(t);
    if (m1 != null) return int.tryParse(m1.group(1)!) ?? 60;

    // "1:30 / 3:50 min/set" -> หยาบๆให้ ~45 นาที
    final reg2 = RegExp(r'(\d{1,2}):(\d{2})');
    final m2 = reg2.firstMatch(t);
    if (m2 != null) {
      final mm = int.tryParse(m2.group(1)!) ?? 0;
      final ss = int.tryParse(m2.group(2)!) ?? 0;
      final tot = mm + (ss >= 30 ? 1 : 0); // ปัดขึ้นหยาบๆ
      return (tot <= 0 ? 45 : tot);
    }

    return 60;
  }

  // ใช้ "floating time" (ไม่มี Z/TZID) ให้ระบบผู้ใช้ตีความตามโซนเวลาเครื่อง
  String icsDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}00';
  }

  final buffer = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//RMApp//TrainingPlan//TH')
    ..writeln('CALSCALE:GREGORIAN');

  // วนทุกสัปดาห์/วัน สร้าง VEVENT
  for (int w = 0; w < totalWeeks; w++) {
    final weekPlan = planByWeeks[w.clamp(0, planByWeeks.length - 1)];
    for (final row in weekPlan) {
      final day = (row['day'] ?? 'Mon').trim();
      final dist = (row['dist'] ?? '-').trim();
      final timeTxt = (row['time'] ?? '-').trim();
      final note = (row['note'] ?? '').trim();

      // ข้ามวันพัก
      if (dist == '-' && note.toLowerCase() == 'rest') continue;

      final startThis = week1StartDate
          .add(Duration(days: (dayIndex(day) - 1) + (7 * w)))
          .copyWith(hour: startHour, minute: 0, second: 0);

      final endThis = startThis.add(Duration(minutes: guessMinutes(timeTxt)));
      final uid = '${startThis.millisecondsSinceEpoch}-${w}-${day}';

      final title = (note.isEmpty || note.toLowerCase() == 'rest')
          ? 'ฝึกวิ่ง $dist'
          : '$note • $dist';

      final descLines = <String>[
        'โปรแกรมวิ่ง $targetKm กม.',
        if (timeTxt.isNotEmpty && timeTxt != '-') 'เวลา: $timeTxt',
        if (note.isNotEmpty) 'หมายเหตุ: $note',
      ];
      final desc = descLines.join('\\n');

      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:$uid')
        ..writeln('DTSTAMP:${_icsDateNow()}')
        ..writeln('DTSTART:${icsDate(startThis)}')
        ..writeln('DTEND:${icsDate(endThis)}')
        ..writeln('SUMMARY:${_escapeICS(title)}')
        ..writeln('DESCRIPTION:${_escapeICS(desc)}')
        ..writeln('END:VEVENT');
    }
  }

  buffer.writeln('END:VCALENDAR');

  final ics = buffer.toString();
  final dataUrl = 'data:text/calendar;charset=utf-8,${Uri.encodeComponent(ics)}';

  // ใช้ data: URL ทุกแพลตฟอร์ม (ง่ายและไม่ต้องพึ่ง dart:io)
  await launchUrlString(dataUrl, mode: LaunchMode.externalApplication);
}

/// ---------- Utils ----------
String _escapeICS(String input) {
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');
}

String _icsDateNow() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}T${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

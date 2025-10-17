// lib/src/widgets/calendar_helper.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:device_calendar/device_calendar.dart' as devcal;
import 'package:timezone/timezone.dart' as tz;
import 'package:add_2_calendar/add_2_calendar.dart';

/// ---------- Utilities ----------
String _escapeICS(String input) {
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');
}

int _dayIndex(String day) {
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

int _guessMinutes(String? timeText) {
  if (timeText == null || timeText.trim().isEmpty || timeText == '-') return 60;
  final t = timeText.toLowerCase();

  final reg1 = RegExp(r'(\d+)\s*min');
  final m1 = reg1.firstMatch(t);
  if (m1 != null) return int.tryParse(m1.group(1)!) ?? 60;

  final reg2 = RegExp(r'(\d{1,2}):(\d{2})');
  final m2 = reg2.firstMatch(t);
  if (m2 != null) {
    final mm = int.tryParse(m2.group(1)!) ?? 0;
    final ss = int.tryParse(m2.group(2)!) ?? 0;
    final tot = mm + (ss >= 30 ? 1 : 0);
    return (tot <= 0 ? 45 : tot);
  }
  return 60;
}

/// ---------- A) .ICS export (สำหรับ emulator/web) ----------
Future<void> exportTrainingPlanToICS({
  required DateTime week1StartDate,
  required int totalWeeks,
  required int targetKm,
  required List<List<Map<String, String>>> planByWeeks,
  int startHour = 6,
}) async {
  String two(int n) => n.toString().padLeft(2, '0');
  String icsDate(DateTime dt) =>
      '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}00';

  final buffer = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//RMApp//TrainingPlan//TH');

  for (int w = 0; w < totalWeeks; w++) {
    final weekPlan = planByWeeks[w.clamp(0, planByWeeks.length - 1)];
    for (final row in weekPlan) {
      final day = row['day'] ?? 'Mon';
      final dist = row['dist'] ?? '-';
      final timeTxt = row['time'] ?? '-';
      final note = row['note'] ?? '';

      if (dist.trim() == '-' && note.toLowerCase() == 'rest') continue;

      final startLocal = week1StartDate
          .add(Duration(days: (_dayIndex(day) - 1) + (7 * w)))
          .copyWith(hour: startHour, minute: 0, second: 0);

      final endLocal = startLocal.add(Duration(minutes: _guessMinutes(timeTxt)));
      final uid = '${startLocal.millisecondsSinceEpoch}-${w}-${day}';

      final title = note.isEmpty || note.toLowerCase() == 'rest'
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
        ..writeln('DTSTAMP:${icsDate(DateTime.now())}')
        ..writeln('DTSTART:${icsDate(startLocal)}')
        ..writeln('DTEND:${icsDate(endLocal)}')
        ..writeln('SUMMARY:${_escapeICS(title)}')
        ..writeln('DESCRIPTION:${_escapeICS(desc)}')
        ..writeln('END:VEVENT');
    }
  }

  buffer.writeln('END:VCALENDAR');
  final ics = buffer.toString();

  if (kIsWeb) {
    final dataUrl = 'data:text/calendar;charset=utf-8,${Uri.encodeComponent(ics)}';
    await launchUrlString(dataUrl, mode: LaunchMode.externalApplication);
    return;
  }

  final filename = 'training_plan_${DateTime.now().millisecondsSinceEpoch}.ics';
  File file;

  try {
    if (Platform.isAndroid) {
      final downloads = Directory('/sdcard/Download');
      if (await downloads.exists()) {
        file = File('${downloads.path}/$filename');
        await file.writeAsString(ics, encoding: const Utf8Codec());
      } else {
        final dir = await getTemporaryDirectory();
        file = File('${dir.path}/$filename');
        await file.writeAsString(ics, encoding: const Utf8Codec());
      }
    } else {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/$filename');
      await file.writeAsString(ics, encoding: const Utf8Codec());
    }
    await OpenFilex.open(file.path);
  } catch (_) {}
}

/// เปิดหน้า Import และหน้า “สร้างเล่มใหม่” ของ Google Calendar
Future<void> openGoogleCalendarImportPage() async {
  const url = 'https://calendar.google.com/calendar/u/0/r/settings/import';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

Future<void> openGoogleCalendarCreateCalendarPage() async {
  const url = 'https://calendar.google.com/calendar/u/0/r/settings/createcalendar';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

/// นัดเดียวแบบ recurring (ตัวอย่าง)
Future<void> addStartProgramToCalendar({
  required DateTime startDate,
  required int trainingWeeks,
  required int targetKm,
}) async {
  final title = 'เริ่มโปรแกรมวิ่ง $targetKm กม.';
  final desc  = 'โปรแกรมฝึกวิ่ง $targetKm กม. ระยะเวลา $trainingWeeks สัปดาห์';
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

  String two(int n) => n.toString().padLeft(2, '0');
  String fmt(DateTime dt) =>
      '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}00';
  final dates = '${fmt(startDate)}/${fmt(endDate)}';

  final url =
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(title)}'
      '&details=${Uri.encodeComponent('$desc\\n(นัดหมายซ้ำรายสัปดาห์)')}'
      '&dates=$dates';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

/// ---------- B) จัดการ “เล่ม (Calendar)” บนอุปกรณ์ ----------
Future<List<devcal.Calendar>> getWritableCalendars() async {
  final plugin = devcal.DeviceCalendarPlugin();

  final perms = await plugin.requestPermissions();
  if (perms.data != true) {
    throw 'ผู้ใช้ไม่อนุญาตสิทธิ์ปฏิทิน';
  }

  final calsResult = await plugin.retrieveCalendars();

  // เดิม: where((c) => (c.isReadOnly ?? true) == false)  // ตัดค่า null ทิ้งไปหมด
  // ใหม่: รับทุกอันที่ "ไม่ใช่ true" (คือ false หรือ null)
  final List<devcal.Calendar> calendars =
      (calsResult.data ?? <devcal.Calendar>[])
          .where((devcal.Calendar c) => c.isReadOnly != true)
          .toList()
        ..sort((a, b) =>
            ('${a.accountName ?? ''}${a.name ?? ''}')
                .compareTo('${b.accountName ?? ''}${b.name ?? ''}'));

  return calendars;
}


/// dialog ให้เลือกเล่ม + ปุ่มไป “สร้างเล่มใหม่” และ “นำเข้า .ics”
// แทนที่ของเดิมทั้งฟังก์ชันนี้
Future<String?> pickCalendarIdDialog(BuildContext context) async {
  // ฟังก์ชันดึงรายชื่อ (เรียกซ้ำได้)
  Future<List<devcal.Calendar>> _load() async {
    try {
      return await getWritableCalendars(); // เราเรียก retrieve ทุกครั้งอยู่แล้ว
    } catch (_) {
      return <devcal.Calendar>[];
    }
  }

  final cals = await _load();

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      // ให้ dialog รีเฟรชตัวเองได้
      return StatefulBuilder(
        builder: (ctx, setState) {
          List<devcal.Calendar> calendars = cals;

          Future<void> _refresh() async {
            final latest = await _load();
            setState(() => calendars = latest);
          }

          return SimpleDialog(
            titlePadding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 0),
            contentPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            title: Row(
              children: [
                const Expanded(child: Text('เลือกเล่มปฏิทิน')),
                IconButton(
                  tooltip: 'รีเฟรชรายชื่อ',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                )
              ],
            ),
            children: [
              if (calendars.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('ยังไม่พบเล่มที่เขียนได้ (ลองกดรีเฟรช หรือเปิด Google Calendar แล้ว Refresh)'),
                ),
              for (final c in calendars)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c.id),
                  child: Text(
                    '${c.name ?? 'Calendar'}'
                    '${(c.accountName ?? '').isNotEmpty ? ' • ${c.accountName}' : ''}',
                  ),
                ),
              const Divider(),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx, null);
                  openGoogleCalendarCreateCalendarPage();
                },
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 8),
                    Text('สร้างเล่มใหม่ใน Google Calendar'),
                  ],
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx, null);
                  openGoogleCalendarImportPage();
                },
                child: const Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('นำเข้าไฟล์ .ics ไปยัง Google Calendar'),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}


/// load/save calendarId ที่เลือกไว้
Future<String?> loadSelectedCalendarId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('calendarId');
}

Future<void> saveSelectedCalendarId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('calendarId', id);
}

/// ใส่ทั้งโปรแกรมลง “เล่มที่ระบุ”
Future<void> bulkInsertToDeviceCalendar({
  String? calendarId,
  required DateTime week1StartDate,
  required int totalWeeks,
  required int targetKm,
  required List<List<Map<String, String>>> planByWeeks,
  int startHour = 6,
}) async {
  final plugin = devcal.DeviceCalendarPlugin();
  final perms = await plugin.requestPermissions();
  if (perms.data != true) throw 'ผู้ใช้ไม่อนุญาตสิทธิ์ปฏิทิน';

  devcal.Calendar? targetCal;
  final calendars = await getWritableCalendars();
  if (calendars.isEmpty) throw 'ไม่พบปฏิทินที่เขียนได้';

  targetCal = calendarId != null
      ? calendars.firstWhere((c) => c.id == calendarId, orElse: () => calendars.first)
      : calendars.first;

  for (int w = 0; w < totalWeeks; w++) {
    final weekPlan = planByWeeks[w.clamp(0, planByWeeks.length - 1)];
    for (final row in weekPlan) {
      final day = row['day'] ?? 'Mon';
      final dist = row['dist'] ?? '-';
      final timeTxt = row['time'] ?? '-';
      final note = row['note'] ?? '';

      if (dist.trim() == '-' && note.toLowerCase() == 'rest') continue;

      final startLocal = week1StartDate
          .add(Duration(days: (_dayIndex(day) - 1) + (7 * w)))
          .copyWith(hour: startHour, minute: 0, second: 0);
      final endLocal = startLocal.add(Duration(minutes: _guessMinutes(timeTxt)));

      final tzStart = tz.TZDateTime.from(startLocal, tz.local);
      final tzEnd = tz.TZDateTime.from(endLocal, tz.local);

      final title = note.isEmpty || note.toLowerCase() == 'rest'
          ? 'ฝึกวิ่ง $dist'
          : '$note • $dist';

      final descLines = <String>[
        'โปรแกรมวิ่ง $targetKm กม.',
        if (timeTxt.isNotEmpty && timeTxt != '-') 'เวลา: $timeTxt',
        if (note.isNotEmpty) 'หมายเหตุ: $note',
      ];

      final ev = devcal.Event(
        targetCal.id,
        title: title,
        description: descLines.join('\n'),
        start: tzStart,
        end: tzEnd,
      );

      await plugin.createOrUpdateEvent(ev);
    }
  }
}

/// ส่งเฉพาะ “วันนี้” ไปเล่มที่เลือก
Future<void> addTodaysPlanToDeviceCalendar({
  required DateTime week1StartDate,
  required int totalWeeks,
  required int targetKm,
  required List<List<Map<String, String>>> planByWeeks,
  String? calendarId,
  int startHour = 6,
}) async {
  final plugin = devcal.DeviceCalendarPlugin();
  final perms = await plugin.requestPermissions();
  if (perms.data != true) throw 'ผู้ใช้ไม่อนุญาตสิทธิ์ปฏิทิน';

  final calendars = await getWritableCalendars();
  if (calendars.isEmpty) throw 'ไม่พบปฏิทินที่เขียนได้';
  final targetCal = calendarId != null
      ? calendars.firstWhere((c) => c.id == calendarId, orElse: () => calendars.first)
      : calendars.first;

  final today = DateTime.now();
  final d0 = DateTime(week1StartDate.year, week1StartDate.month, week1StartDate.day);
  final diffDays = today.difference(d0).inDays;
  if (diffDays < 0) throw 'ยังไม่ถึงสัปดาห์ที่ 1';
  final weekIndex = (diffDays ~/ 7);
  if (weekIndex >= totalWeeks) throw 'เกินช่วงโปรแกรมแล้ว';

  const names = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
  final weekPlan = planByWeeks[weekIndex.clamp(0, planByWeeks.length-1)];
  final row = weekPlan.firstWhere(
    (r) => (r['day'] ?? '') == names[today.weekday],
    orElse: () => {},
  );
  if (row.isEmpty) throw 'วันนี้ไม่มีรายการในแผน';

  final dist = row['dist'] ?? '-';
  final note = (row['note'] ?? '').trim();
  final timeTxt = row['time'] ?? '-';
  if (dist.trim() == '-' && note.toLowerCase() == 'rest') {
    throw 'วันนี้เป็นวันพัก';
  }

  final startLocal = DateTime(today.year, today.month, today.day, startHour, 0);
  final endLocal = startLocal.add(Duration(minutes: _guessMinutes(timeTxt)));
  final tzStart = tz.TZDateTime.from(startLocal, tz.local);
  final tzEnd = tz.TZDateTime.from(endLocal, tz.local);

  final title = note.isEmpty ? 'ฝึกวิ่ง $dist' : '$note • $dist';
  final desc = [
    'โปรแกรมวิ่ง $targetKm กม.',
    if (timeTxt.isNotEmpty && timeTxt != '-') 'เวลา: $timeTxt',
    if (note.isNotEmpty) 'หมายเหตุ: $note',
  ].join('\n');

  final ev = devcal.Event(
    targetCal.id,
    title: title,
    description: desc,
    start: tzStart,
    end: tzEnd,
  );
  await plugin.createOrUpdateEvent(ev);
}

Future<void> debugPrintCalendars() async {
  try {
    final plugin = devcal.DeviceCalendarPlugin();
    final perms = await plugin.requestPermissions();
    if (perms.data != true) {
      print('Calendar permission not granted');
      return;
    }
    final res = await plugin.retrieveCalendars();
    final list = res.data ?? <devcal.Calendar>[];
    print('---- Calendars from provider ----');
    for (final c in list) {
      print('id=${c.id} | name=${c.name} | account=${c.accountName} | isReadOnly=${c.isReadOnly}');
    }
  } catch (e) {
    print('debugPrintCalendars error: $e');
  }
}

// lib/src/widgets/calendar_helper.dart
import 'dart:async';            // <-- ✅ เพิ่มอันนี้
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

/// ========= Utilities =========

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

/// ========= A) .ICS export =========

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
      final uid = '${startLocal.millisecondsSinceEpoch}-$w-$day';

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

Future<void> openGoogleCalendarImportPage() async {
  const url = 'https://calendar.google.com/calendar/u/0/r/settings/import';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

Future<void> openGoogleCalendarCreateCalendarPage() async {
  const url = 'https://calendar.google.com/calendar/u/0/r/settings/createcalendar';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

Future<void> addStartProgramToCalendar({
  required DateTime startDate,
  required int trainingWeeks,
  required int targetKm,
}) async {
  final title = 'เริ่มโปรแกรมวิ่ง $targetKm กม.';
  final desc  = 'โปรแกรมฝึกวิ่ง $targetKm กม. ระยะเวลา $trainingWeeks สัปดาห์';
  final endDate  = startDate.add(const Duration(hours: 1));
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

/// ========= B) Device calendars =========

final _plugin = devcal.DeviceCalendarPlugin();

Future<bool> _ensurePerms() async {
  final has = await _plugin.hasPermissions();
  if (has.isSuccess == true && has.data == true) return true;
  final req = await _plugin.requestPermissions();
  return req.isSuccess == true && req.data == true;
}

bool _calendarPermGranted = false;

Future<List<devcal.Calendar>> getWritableCalendars() async {
  final plugin = devcal.DeviceCalendarPlugin();

  if (!_calendarPermGranted) {
    final perms = await plugin.requestPermissions();
    _calendarPermGranted = (perms.data == true);
    if (!_calendarPermGranted) {
      throw 'ผู้ใช้ไม่อนุญาตสิทธิ์ปฏิทิน';
    }
  }

  // เรียก provider ทุกครั้งเพื่อดึงเล่มล่าสุด
  final calsResult = await plugin.retrieveCalendars();

  final List<devcal.Calendar> calendars =
      (calsResult.data ?? <devcal.Calendar>[])
          .where((devcal.Calendar c) => c.isReadOnly != true)
          .toList()
        ..sort((a, b) =>
            ('${a.accountName ?? ''}${a.name ?? ''}')
                .compareTo('${b.accountName ?? ''}${b.name ?? ''}'));

  return calendars;
}

/// dialog เลือกเล่ม (มีปุ่ม Refresh / เปิดแอป Calendar / Auto-scan)
Future<String?> pickCalendarIdDialog(BuildContext context) async {
  Future<List<devcal.Calendar>> _load() async {
    try {
      return await getWritableCalendars();
    } catch (_) {
      return <devcal.Calendar>[];
    }
  }

  // โหลดรอบแรก
  List<devcal.Calendar> calendars = await _load();

  // ⬇️ showDialog คืน Future<String?>
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      bool isScanning = false;
      int scannedSec = 0;
      Timer? timer;

      Future<void> _refresh(StateSetter setState) async {
        final latest = await _load();
        setState(() => calendars = latest);
      }

      Future<void> _startAutoScan(StateSetter setState) async {
        if (isScanning) return;
        isScanning = true;
        scannedSec = 0;
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 2), (t) async {
          scannedSec += 2;
          final latest = await _load();
          setState(() {
            calendars = latest;
          });
          if (calendars.isNotEmpty || scannedSec >= 30) {
            isScanning = false;
            t.cancel();
          }
        });
      }

      return StatefulBuilder(
        builder: (ctx, setState) {
          final hasAny = calendars.isNotEmpty;

          return SimpleDialog(
            titlePadding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 0),
            contentPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            title: Row(
              children: [
                const Expanded(child: Text('เลือกเล่มปฏิทิน')),
                IconButton(
                  tooltip: 'รีเฟรชรายชื่อ',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refresh(setState),
                ),
              ],
            ),
            children: [
              if (!hasAny)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ยังไม่พบเล่ม (ลองกดรีเฟรช หรือเปิด Google Calendar แล้วกลับมา)'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _startAutoScan(setState),
                        icon: const Icon(Icons.search),
                        label: Text(
                          isScanning
                              ? 'เริ่มค้นหาเล่มใหม่อัตโนมัติ… (${scannedSec}s)'
                              : 'เริ่มค้นหาเล่มใหม่อัตโนมัติ (30 วินาที)',
                        ),
                      ),
                    ],
                  ),
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
                onPressed: () async {
                  const url = 'https://calendar.google.com/calendar/';
                  await launchUrlString(url, mode: LaunchMode.externalApplication);
                },
                child: const Row(
                  children: [
                    Icon(Icons.open_in_new, size: 18),
                    SizedBox(width: 8),
                    Text('เปิดแอป Calendar (ช่วยกระตุ้นซิงก์)'),
                  ],
                ),
              ),
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

  // ยกเลิก timer ถ้ามี (เมื่อ dialog ปิด)
  // (ไม่ต้อง .then กับ StatefulBuilder แล้ว)
  return result;
}

Future<String?> loadSelectedCalendarId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('calendarId');
}

Future<void> saveSelectedCalendarId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('calendarId', id);
}

Future<void> bulkInsertToDeviceCalendar({
  String? calendarId,
  required DateTime week1StartDate,
  required int totalWeeks,
  required int targetKm,
  required List<List<Map<String, String>>> planByWeeks,
  int startHour = 6,
}) async {
  if (!await _ensurePerms()) throw 'ผู้ใช้ไม่อนุญาตสิทธิ์ปฏิทิน';

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

      await _plugin.createOrUpdateEvent(ev);
    }
  }
}

Future<void> addTodaysPlanToDeviceCalendar({
  required DateTime week1StartDate,
  required int totalWeeks,
  required int targetKm,
  required List<List<Map<String, String>>> planByWeeks,
  String? calendarId,
  int startHour = 6,
}) async {
  if (!await _ensurePerms()) throw 'ผู้ใช้ไม่อนุญาตสิทธิ์ปฏิทิน';

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
  await _plugin.createOrUpdateEvent(ev);
}

Future<void> debugPrintCalendars() async {
  try {
    if (!await _ensurePerms()) {
      print('Calendar permission not granted');
      return;
    }
    final res = await _plugin.retrieveCalendars();
    final list = res.data ?? <devcal.Calendar>[];
    print('---- Calendars from provider ----');
    for (final c in list) {
      print('id=${c.id} | name=${c.name} | account=${c.accountName} | isReadOnly=${c.isReadOnly}');
    }
  } catch (e) {
    print('debugPrintCalendars error: $e');
  }
}

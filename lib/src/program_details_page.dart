import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

// ===== Orange palette (แต่งเฉพาะสี/สไตล์) =====
const _orange1 = Color(0xFFFF6F00);
const _orange2 = Color(0xFFFF8F00);
const _bgTop = Color(0xFFFAFAFA);
const _bgBot = Color(0xFFF5F5F5);
const _textMain = Color(0xFF212121);
const _textMuted = Color(0xFF616161);
const _line = Color(0xFFECECEC);

class ProgramDetailsPage extends StatelessWidget {
  final String userId;
  final DocumentSnapshot program;

  const ProgramDetailsPage({
    super.key,
    required this.userId,
    required this.program,
  });

  @override
  Widget build(BuildContext context) {
    final programData = program.data() as Map<String, dynamic>;
    final programName = programData['targetKm'].toString();
    final totalWeeks = programData['totalWeeks'] as int;

    // Enhanced logging
    developer.log(
      'Opening Program Details',
      name: 'com.example.rmapp.program_details',
      error: 'UserID: $userId, ProgramID: ${program.id}',
    );

    final firestorePath = 'users/$userId/Program/${program.id}/Training';

    return Scaffold(
      appBar: AppBar(
        title: Text('รายละเอียดโปรแกรม'),
        backgroundColor: _orange1,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBot],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('Program')
              .doc(program.id)
              .collection('Training')
              .orderBy('date') // Corrected field name
              .snapshots(),
          builder: (context, snapshot) {
            // Enhanced error and data handling
            if (snapshot.hasError) {
              developer.log(
                'Firestore Stream Error',
                name: 'com.example.rmapp.program_details',
                error: snapshot.error,
                stackTrace: snapshot.stackTrace,
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'เกิดข้อผิดพลาดในการโหลดข้อมูล:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700], height: 1.5),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'ไม่พบข้อมูลการฝึก\n\nตรวจสอบที่ Firestore Path:\n$firestorePath',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            final tasks = snapshot.data!.docs;
            final completedTasks = tasks.where((task) {
              final data = task.data() as Map<String, dynamic>;
              // Corrected field name and logic
              return (data['status'] as String?)?.toLowerCase() == 'completed';
            }).length;
            final progress = tasks.isEmpty
                ? 0.0
                : completedTasks / tasks.length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'โปรแกรมวิ่ง $programName km',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _textMain,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ระยะเวลา: $totalWeeks สัปดาห์',
                              style: TextStyle(color: _textMuted, fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 12,
                                      backgroundColor: _line,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            _orange1,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _orange1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ความสำเร็จ',
                              style: TextStyle(color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final task = tasks[index];
                    final taskData = task.data() as Map<String, dynamic>;

                    // Corrected field names
                    final week = taskData['week'] as int;
                    final dayOfWeek = taskData['dayOfWeek'] as String;
                    final taskDescription = taskData['type'] as String;
                    final distance = taskData['distance'] as String;
                    final time = taskData['time'] as String;
                    final isCompleted =
                        (taskData['status'] as String?)?.toLowerCase() ==
                        'completed';
                    final completedDate = taskData['loggedAt'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCompleted
                              ? _orange2.withOpacity(0.2)
                              : Colors.grey.shade200,
                          foregroundColor: isCompleted ? _orange1 : _textMuted,
                          child: Text(
                            'ส.$week\n$dayOfWeek', // Updated display
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '$taskDescription: $distance', // Updated display
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _textMain,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('เวลา: $time'), // Added time display
                            if (isCompleted && completedDate != null)
                              Text(
                                'สำเร็จเมื่อ: ${DateFormat.yMd('th').format(completedDate.toDate())}',
                              )
                            else
                              const Text('ยังไม่สำเร็จ'),
                          ],
                        ),
                        trailing: Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isCompleted ? Colors.green : Colors.grey,
                        ),
                      ),
                    );
                  }, childCount: tasks.length),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
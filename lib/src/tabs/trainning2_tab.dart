import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:rmapp/src/training_repo.dart';
import 'package:rmapp/src/trainingtask_page.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:rmapp/src/trainingtask_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Trainning2Tab extends StatefulWidget {
  const Trainning2Tab({super.key});

  @override
  State<Trainning2Tab> createState() => _Trainning2TabState();
}

class _Trainning2TabState extends State<Trainning2Tab> {
  String _Runningtarget = '-'; // เปลี่ยนชื่อให้ตรงกับ Field ใน Firestore
  String _Timetarget = '-'; // เปลี่ยนชื่อให้ตรงกับ Field ใน Firestore
  String _Runningtype = '-'; // เปลี่ยนชื่อให้ตรงกับ Field ใน Firestore
  String? _currentProgramId; // เก็บ Program ID ที่ใช้งานอยู่

  @override
  void initState() {
    super.initState();
    _loadProgramId(); // เรียกใช้ฟังก์ชันใหม่
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProgramId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // เรียกฟังก์ชันดึง Program ID ปัจจุบัน
    final programId = await TrainingRepo.fetchCurrentProgramId(user.uid);

    setState(() {
      _currentProgramId = programId?.first;
    });

    if (_currentProgramId != null) {
      print("✅ Program ID ล่าสุดที่ใช้: $_currentProgramId");
      getTodaydata();
    } else {
      print("⚠️ ไม่พบ Program ID ปัจจุบันสำหรับผู้ใช้นี้");
    }
  }

  // ========== ฟังก์ชันดึงข้อมูลแผนวันนี้ ==========
  void getTodaydata() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final programId = _currentProgramId;

    if (userId == null || programId == null) {
      // อาจแสดงข้อความว่า "ยังไม่มีโปรแกรมที่ใช้งานอยู่"
      return;
    }

    // 1. กำหนด Document ID เป็นวันที่ในรูปแบบ YYYY-MM-DD (ใช้สำหรับ Firestore Document ID)
    // ⚠️ แก้ไขตรงนี้: เปลี่ยนจาก 'dd-MM-yyyy' เป็น 'yyyy-MM-dd'
    final now = DateTime.now();
    final todayId = DateFormat('dd-MM-yyyy').format(now);

    // 2. สร้าง Path ไปยังเอกสาร Training วันนี้
    // Path: users/{userId}/Program/{programId}/Training/{todayId}
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Program')
        .doc(programId)
        .collection('Training')
        .doc(todayId); // ใช้ todayId ที่เป็น yyyy-MM-dd

    try {
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;

        if (!mounted) return;
        setState(() {
          // ใช้ชื่อ Field ที่ถูกต้องจาก Firestore
          _Runningtarget = data['distance'] as String? ?? 'N/A';
          _Timetarget = data['time'] as String? ?? 'N/A';
          _Runningtype = data['type'] as String? ?? 'Rest';
        });
      } else {
        // กรณีไม่พบแผนของวันนี้
        if (!mounted) return;
        setState(() {
          _Runningtarget = 'N/A';
          _Timetarget = 'N/A';
          _Runningtype = 'No Plan';
        });
      }
    } catch (e) {
      print("Error fetching today's training data: $e");
      // จัดการข้อผิดพลาด
      if (!mounted) return;
      setState(() {
        _Runningtarget = 'Error';
        _Timetarget = 'Error';
        _Runningtype = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //Temp variable
    const String taskName = "Morning Run";
    const String distance = "5 km";
    const String time = "3 min";

    return Scaffold(
      appBar: AppBar(title: const Text('Training 2 Tab')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Card for Speed Display (from original code) ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Adjusted radius for better look
                ),
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  // Moved Padding here, outside the inner Column
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    // Removed extra Column for simplicity, keeping content in Row
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            "Today Task",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),

                          Text(
                            _Runningtype,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30, thickness: 1), // Separator line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: Container(
                              height: 150, // Fixed height for visual balance
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                  255,
                                  245,
                                  245,
                                  245,
                                ), // Blue
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Distance',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _Runningtarget,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Container(
                              height: 150, // Fixed height for visual balance
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                  255,
                                  245,
                                  245,
                                  245,
                                ), // Blue
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Time',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _Timetarget,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 30, thickness: 1),

                      //Date and time display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            "Date: ${DateTime.now().toLocal().toString().split(' ')[0]}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),

                          Text(
                            "Time: ${TimeOfDay.now().format(context)}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),

                          //
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20), // Spacer between the cards

              const SizedBox(height: 20), // Spacer between the cards
              // --- Card for Today Task (Implementing your design sketch) ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Consistent radius
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. "Today Task" and "Task name"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Today Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' "$taskName"',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 20, thickness: 1), // Separator line
                      // 2. "Distance" and "Time" labels
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            'Distance',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Text(
                            'Time',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 3. Distance and Time values
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            ' "$distance"',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            ' "$time"',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 4. "Start" Button
                      ElevatedButton(
                        onPressed: () {
                          // Action to perform on button press (e.g., start training)
                          print('Start button pressed!');
                        },
                        style: ElevatedButton.styleFrom(
                          // You can customize the button style here
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              //Button Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Consistent radius
                ),
                elevation: 4,

                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ScreenTwo()),
                    );
                    print('Start button pressed!');
                  },
                  style: ElevatedButton.styleFrom(
                    // You can customize the button style here
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    backgroundColor: Colors.lightBlueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Train',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    throw UnimplementedError();
  }
}

class Vector3 {
  final double x;
  final double y;
  final double z;
  const Vector3(this.x, this.y, this.z);
}

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:rmapp/src/trainingtask_page.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

class Trainning2Tab extends StatefulWidget {
  const Trainning2Tab({super.key});

  @override
  State<Trainning2Tab> createState() => _Trainning2TabState();
}

class _Trainning2TabState extends State<Trainning2Tab> {
  double _currentSpeed = 0.0; // m/s
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  // --- Sensor State ---
  Vector3 _accelerometerData = const Vector3(0, 0, 0);
  Vector3 _gyroscopeData = const Vector3(0, 0, 0);
  double _gForce = 0.0; // g value (≈ total acceleration / 9.8)

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // 1. ตรวจสอบว่าเปิด location service หรือยัง
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    // 2. ขอ permission
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // 3. ตั้งค่า location update ให้แม่นยำ
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000, // update ทุก 1 วินาที
      distanceFilter: 0,
    );

    // 4. เริ่มรับข้อมูล location
    _locationSubscription = _location.onLocationChanged.listen((
      LocationData data,
    ) {
      if (!mounted) return;
      setState(() {
        _currentSpeed = (data.speed ?? 0.0).abs(); // m/s
      });
      debugPrint(
        'Speed: ${data.speed} m/s, Lat: ${data.latitude}, Lng: ${data.longitude}',
      );
    });
  }

  // --------------------------------------------------------------------------
  // --- Sensor Methods (Gyroscope and Accelerometer) ---
  void _startSensorStreams() {
    // Accelerometer (รวมแรงโน้มถ่วง)
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((AccelerometerEvent event) {
      if (!mounted) return;
      // คำนวณแรงรวมทั้งหมด (รวมแรง g)
      final double totalForce = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      setState(() {
        _accelerometerData = Vector3(event.x, event.y, event.z);
        _gForce = totalForce / 9.8; // แปลงเป็นหน่วย g
      });
    });

    // Gyroscope
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((GyroscopeEvent event) {
      if (!mounted) return;
      setState(() {
        _gyroscopeData = Vector3(event.x, event.y, event.z);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    //Temp variable
    const String taskName = "Morning Run";
    const String distance = "5 km";
    const String time = "30 min";

    final speedKmh = _currentSpeed * 3.6; // แปลง m/s เป็น km/h
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAFAFA),
              Color(0xFFF5F5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // หัวข้อ
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

                const SizedBox(height: 24),

                // การ์ดแสดง Task
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        color: Colors.black.withOpacity(.06),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ชื่อ Task
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6F00),
                                  Color(0xFFFF8F00),
                                ],
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
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              taskName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF212121),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Long Run',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Distance และ Time
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6F00).withOpacity(.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFF6F00).withOpacity(.15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'ระยะทาง',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFF757575),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    distance,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF212121),
                                      letterSpacing: -0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6F00).withOpacity(.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFF6F00).withOpacity(.15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'เวลา',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFF757575),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    time,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF212121),
                                      letterSpacing: -0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // การ์ดข้อมูลเพิ่มเติม
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 3),
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
                        value: DateTime.now().toLocal().toString().split(' ')[0],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: const Color(0xFFE0E0E0),
                      ),
                      _InfoItem(
                        icon: Icons.access_time,
                        label: 'เวลา',
                        value: TimeOfDay.now().format(context),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ปุ่ม Train ใหญ่
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF6F00),
                        Color(0xFFFF8F00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6F00).withOpacity(.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ScreenTwo()),
                      );
                      print('Train button pressed!');
                    },
                    icon: const Icon(Icons.play_arrow, size: 32),
                    label: Text(
                      'เริ่มฝึกเลย',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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

                const SizedBox(height: 16),

                // ปุ่ม Start เล็ก (ถ้าต้องการเก็บไว้)
                OutlinedButton.icon(
                  onPressed: () {
                    print('Start button pressed!');
                  },
                  icon: const Icon(Icons.timer, size: 20),
                  label: const Text('เริ่มจับเวลา'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6F00),
                    side: const BorderSide(
                      color: Color(0xFFFF6F00),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
        Icon(
          icon,
          size: 24,
          color: const Color(0xFFFF6F00),
        ),
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

class Vector3 {
  final double x;
  final double y;
  final double z;
  const Vector3(this.x, this.y, this.z);
}
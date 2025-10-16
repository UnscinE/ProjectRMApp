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
    _accelSubscription =
        accelerometerEventStream(
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
    _gyroSubscription =
        gyroscopeEventStream(
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
    const String time = "3 min";

    final speedKmh = _currentSpeed * 3.6; // แปลง m/s เป็น km/h
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
                            "Long Run",
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
                                    '50 km',
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
                                    '30 min',
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

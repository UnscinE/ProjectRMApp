import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllProgramsPage extends StatelessWidget {
  final String userId;

  const AllProgramsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการฝึกทั้งหมด')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('Program')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ไม่มีประวัติการฝึก'));
          }

          final programs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              final programData = program.data() as Map<String, dynamic>;
              final programName = programData['name'] ?? 'โปรแกรม';
              final duration = programData['duration'] ?? 'N/A';
              final progress =
                  (programData['progress'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(programName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$duration สัปดาห์'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${(progress * 100).toStringAsFixed(0)}% สำเร็จ'),
                    ],
                  ),
                  onTap: () {
                    // TODO: Navigate to program details page
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

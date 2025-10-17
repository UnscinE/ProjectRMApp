import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// หน่วยระยะทางของผู้ใช้
enum DistanceUnit { km, mi }

class AccountTab extends StatefulWidget {
  final String email;
  final String? displayName;

  /// callback: ออกจากระบบ
  final VoidCallback? onSignOut;

  /// callback: ลบบัญชี (อาจต้องยืนยันตัวตน/ re-auth ฝั่งคุณ)
  final Future<void> Function()? onDeleteAccount;

  /// callback: ส่งออกข้อมูลการวิ่ง (เช่น สร้าง CSV/อัปโหลด)
  final Future<void> Function()? onExportData;

  /// callback: จัดการเป้าหมาย/แก้ไขโปรแกรมฝึก
  final VoidCallback? onManageGoals;

  /// callback: เปิดหน้า “ประวัติการวิ่ง”
  final VoidCallback? onViewHistory;

  const AccountTab({
    super.key,
    required this.email,
    this.displayName,
    this.onSignOut,
    this.onDeleteAccount,
    this.onExportData,
    this.onManageGoals,
    this.onViewHistory,
  });

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  bool _loading = true;

  // --- ค่าที่เก็บใน SharedPreferences ---
  DistanceUnit _unit = DistanceUnit.km;
  ThemeMode _themeMode = ThemeMode.system;
  bool _notifDaily = true;     // แจ้งเตือนการวิ่งประจำวัน
  bool _notifWeekly = true;    // สรุปรายสัปดาห์
  bool _autoSync = true;       // ซิงก์อัตโนมัติ
  bool _imuConnected = false;  // สถานะเชื่อมต่อ IMU/อุปกรณ์ (mock)
  String? _nickname;           // ชื่อที่โชว์ในโปรไฟล์ (แก้ได้)

  // --- ตัวอย่างสถิติ (คุณอาจดึงจาก repo/service ของจริงแทน) ---
  double _totalDistanceKm = 0; // ระยะรวมทั้งหมด (km)
  int _weeklyStreak = 0;       // วัน/สัปดาห์ติดกันที่ซ้อมสำเร็จ

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _unit = (prefs.getString('unit') ?? 'km') == 'mi' ? DistanceUnit.mi : DistanceUnit.km;

      final themeStr = prefs.getString('theme') ?? 'system';
      _themeMode = switch (themeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      _notifDaily = prefs.getBool('notifDaily') ?? true;
      _notifWeekly = prefs.getBool('notifWeekly') ?? true;
      _autoSync = prefs.getBool('autoSync') ?? true;
      _imuConnected = prefs.getBool('imuConnected') ?? false;

      _nickname = prefs.getString('nickname') ?? widget.displayName;
      // mock ตัวเลขสถิติเริ่มต้น (ในงานจริงไปดึงจาก backend/Firestore)
      _totalDistanceKm = (prefs.getDouble('totalDistanceKm') ?? 42.0);
      _weeklyStreak = (prefs.getInt('weeklyStreak') ?? 3);

      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unit', _unit == DistanceUnit.km ? 'km' : 'mi');
    await prefs.setString(
        'theme',
        switch (_themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        });
    await prefs.setBool('notifDaily', _notifDaily);
    await prefs.setBool('notifWeekly', _notifWeekly);
    await prefs.setBool('autoSync', _autoSync);
    await prefs.setBool('imuConnected', _imuConnected);
    if (_nickname != null) await prefs.setString('nickname', _nickname!);

    // เก็บ mock stat ด้วย (หากมีการแก้ในหน้าอื่นก็อย่าลืมอัปเดต)
    await prefs.setDouble('totalDistanceKm', _totalDistanceKm);
    await prefs.setInt('weeklyStreak', _weeklyStreak);
  }

  String _initialsFromName(String nameOrEmail) {
    final base = (nameOrEmail.trim().isEmpty) ? 'Runner' : nameOrEmail;
    final parts = base.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0].isNotEmpty ? parts[0][0] : '') +
          (parts[1].isNotEmpty ? parts[1][0] : '');
    }
    // ถ้าเป็นอีเมล ตัดตัวแรกก่อน '@'
    if (base.contains('@')) return base[0].toUpperCase();
    return base.substring(0, 1).toUpperCase();
  }

  String _formatDistance(double km) {
    if (_unit == DistanceUnit.km) {
      return '${km.toStringAsFixed(1)} km';
    } else {
      final miles = km * 0.621371;
      return '${miles.toStringAsFixed(1)} mi';
    }
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname ?? widget.displayName ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อที่แสดง'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'เช่น Boss, Runner, ฯลฯ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
    if (res != null) {
      setState(() => _nickname = res);
      await _savePrefs();
    }
  }

  Future<void> _toggleImuConnection() async {
    // ในโปรเจกต์จริง: เปิดหน้า pair/scan BLE แล้วอัปเดตสถานะ
    setState(() => _imuConnected = !_imuConnected);
    await _savePrefs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_imuConnected ? 'เชื่อมต่อ IMU แล้ว' : 'ตัดการเชื่อมต่อ IMU')),
    );
  }

  Future<void> _confirmSignOut() async {
    if (widget.onSignOut == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (ok == true) {
      widget.onSignOut!.call();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (widget.onDeleteAccount == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบบัญชีผู้ใช้'),
        content: const Text('การลบบัญชีจะลบข้อมูลผู้ใช้ทั้งหมดที่ผูกกับบัญชีนี้ ดำเนินการต่อหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบบัญชี'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.onDeleteAccount!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final nameOrEmail = _nickname?.isNotEmpty == true ? _nickname! : (widget.displayName ?? widget.email);
    final initials = _initialsFromName(nameOrEmail);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ===== โปรไฟล์ผู้ใช้ =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nameOrEmail, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(widget.email, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('แก้ไขชื่อที่แสดง'),
                            onPressed: _editNickname,
                          ),
                          if (widget.onViewHistory != null)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.history),
                              label: const Text('ประวัติการวิ่ง'),
                              onPressed: widget.onViewHistory,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ===== ความคืบหน้า & เป้าหมาย =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สรุปความคืบหน้า', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatChip(
                      label: 'ระยะรวม',
                      value: _formatDistance(_totalDistanceKm),
                      icon: Icons.directions_run,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'สัปดาห์ติดกัน',
                      value: '$_weeklyStreak w',
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.onManageGoals != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onManageGoals,
                      icon: const Icon(Icons.flag),
                      label: const Text('จัดการเป้าหมาย/โปรแกรมฝึก'),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ===== การตั้งค่าแอป & หน่วย =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('การตั้งค่า', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // หน่วยระยะทาง
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('หน่วยระยะทาง'),
                    SegmentedButton<DistanceUnit>(
                      segments: const [
                        ButtonSegment(value: DistanceUnit.km, label: Text('km')),
                        ButtonSegment(value: DistanceUnit.mi, label: Text('mi')),
                      ],
                      selected: <DistanceUnit>{_unit},
                      onSelectionChanged: (s) async {
                        setState(() => _unit = s.first);
                        await _savePrefs();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ธีม
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ธีมของแอป'),
                    DropdownButton<ThemeMode>(
                      value: _themeMode,
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('ตามระบบ')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('สว่าง')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('มืด')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _themeMode = v);
                        await _savePrefs();
                        // หมายเหตุ: ถ้าต้องการให้ธีมเปลี่ยนทั้งแอป ควรดึงค่า ThemeMode นี้จาก Provider / Settings ที่ระดับสูงกว่า
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ===== การแจ้งเตือน & ซิงก์ =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('การแจ้งเตือน & ซิงก์', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('แจ้งเตือนแผนวิ่งประจำวัน'),
                  value: _notifDaily,
                  onChanged: (v) async {
                    setState(() => _notifDaily = v);
                    await _savePrefs();
                  },
                ),
                SwitchListTile(
                  title: const Text('สรุปรายสัปดาห์'),
                  value: _notifWeekly,
                  onChanged: (v) async {
                    setState(() => _notifWeekly = v);
                    await _savePrefs();
                  },
                ),
                SwitchListTile(
                  title: const Text('ซิงก์ข้อมูลอัตโนมัติ'),
                  subtitle: const Text('บันทึกการวิ่งจะถูกซิงก์เมื่อมีอินเทอร์เน็ต'),
                  value: _autoSync,
                  onChanged: (v) async {
                    setState(() => _autoSync = v);
                    await _savePrefs();
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ===== อุปกรณ์/IMU =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('อุปกรณ์ & IMU', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(_imuConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
                  title: Text(_imuConnected ? 'เชื่อมต่อแล้ว' : 'ยังไม่เชื่อมต่อ'),
                  subtitle: const Text('จับคู่กับเซ็นเซอร์ IMU / อุปกรณ์สวมใส่'),
                  trailing: FilledButton(
                    onPressed: _toggleImuConnection,
                    child: Text(_imuConnected ? 'ตัดการเชื่อมต่อ' : 'เชื่อมต่อ'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ===== จัดการข้อมูล & ความเป็นส่วนตัว =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ข้อมูล & ความเป็นส่วนตัว', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.file_download),
                  title: const Text('ส่งออกข้อมูลการวิ่ง (CSV)'),
                  onTap: () async {
                    if (widget.onExportData != null) {
                      await widget.onExportData!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('โปรดเชื่อมต่อ callback การส่งออกข้อมูล')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: const Text('ล้างแคช/ตั้งค่าในเครื่อง'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ล้างข้อมูลในเครื่อง'),
                        content: const Text('ล้างค่าเซตติ้ง/แคชที่เก็บในอุปกรณ์นี้เท่านั้น'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
                          FilledButton.tonal(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('ล้างข้อมูล'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ล้างข้อมูลในเครื่องแล้ว')),
                      );
                      await _loadPrefs();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('ลบบัญชีผู้ใช้'),
                  onTap: widget.onDeleteAccount == null ? null : _confirmDeleteAccount,
                ),
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('ออกจากระบบ'),
                    onPressed: widget.onSignOut == null ? null : _confirmSignOut,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AccountTab extends StatelessWidget {
  final String email;
  final VoidCallback onSignOut;

  const AccountTab({
    super.key,
    required this.email,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('บัญชีผู้ใช้', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // อีเมล
          Text(email, style: Theme.of(context).textTheme.bodyMedium),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: onSignOut,
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }
}
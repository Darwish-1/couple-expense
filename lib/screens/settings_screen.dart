// lib/screens/settings_screen.dart
import 'package:couple_expenses/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import 'login_screen.dart'; // ⬅️ add this

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final theme = Get.find<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account
          _Section(
            title: 'Account',
            children: [
              Obx(() {
                final u = auth.user.value;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(u?.displayName ?? 'Signed in user'),
                  subtitle: Text(u?.email ?? '—'),
                );
              }),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red[300]),
                title: const Text('Sign out'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text('You can sign back in any time.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    await auth.signOut();                 // stop streams + firebase signOut
                    Get.offAll(() => const AuthGate()); // ⬅️ nuke stack → Login
                  }
                },
              ),
            ],
          ),

          // Appearance
          _Section(
            title: 'Appearance',
            children: [
              Obx(() => SwitchListTile(
                    value: theme.isDark.value,
                    onChanged: theme.toggleDark,
                    secondary: const Icon(Icons.dark_mode),
                    title: const Text('Dark mode'),
                  )),
            ],
          ),

          // Preferences (placeholders)
          _Section(
            title: 'Preferences',
            children: [
              SwitchListTile(
                value: true,
                onChanged: (v) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications not wired yet')),
                  );
                },
                secondary: const Icon(Icons.notifications_active),
                title: const Text('Notifications'),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: const Text('English'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Localization not wired yet')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: textTheme.titleMedium),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: children),
        ),
      ],
    );
  }
}

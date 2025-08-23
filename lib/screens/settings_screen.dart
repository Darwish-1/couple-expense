// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:couple_expenses/screens/auth_gate.dart';
import 'package:couple_expenses/screens/expenses_root_screen.dart';

import 'package:couple_expenses/controllers/auth_controller.dart';
import 'package:couple_expenses/controllers/theme_controller.dart';
import 'package:couple_expenses/controllers/expenses_root_controller.dart';
import 'package:couple_expenses/controllers/tutorial_coordinator.dart';

import 'package:couple_expenses/services/first_run_tutorial.dart';

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
          // ===== Account =====
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
                    await auth.signOut();
                    Get.offAll(() => const AuthGate());
                  }
                },
              ),
            ],
          ),

          // ===== Appearance =====
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

          // ===== Help & Support =====
          _Section(
            title: 'Tutorial',
            children: [
              // Guided tour – production wording, confirmation, no dev-y text
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Start guided tour'),
                subtitle: const Text('Learn the basics in under a minute'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Start guided tour?'),
                      content: const Text(
                        'We’ll walk you through the core screens and features.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Not now'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Start'),
                        ),
                      ],
                    ),
                  );

                  if (ok != true) return;

                  // Reset flags (device-wide), start sequence, and rebuild the app root.
                  await FirstRunTutorial.reset();

                  if (!Get.isRegistered<TutorialCoordinator>()) {
                    Get.put(TutorialCoordinator(), permanent: true);
                  }
                  TutorialCoordinator.instance.startTutorialSequence();

                  Get.offAll(() => const ExpensesRootScreen());

                  // After mount, open the first tab (My) and show a small toast.
                  Future.delayed(const Duration(milliseconds: 120), () {
                    if (Get.isRegistered<ExpensesRootController>()) {
                      Get.find<ExpensesRootController>().navigateToTab(0);
                    }
                    // Small, unobtrusive confirmation
                 
                  });
                },
                // Optional: long-press in debug builds to just clear flags
                onLongPress: kDebugMode
                    ? () async {
                        await FirstRunTutorial.reset();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tour flags reset')),
                        );
                      }
                    : null,
              ),

              // You can add more help items here (FAQ, Contact support, etc.)
            ],
          ),

          // ===== Preferences (placeholders) =====
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
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifications'),
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
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
          child: Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import 'admin_screen.dart';
import '../controllers/theme_controller.dart';

/// Écran de paramètres simplifié.  L’authentification est désactivée et
/// les paramètres sont limités aux préférences locales.  Vous pouvez
/// étendre cette page pour gérer le thème, la langue ou d’autres options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  bool _isAdmin(User? user) {
    return user != null && user.email == 'admin@mail.com';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('nav_settings')),
      ),
      body: ListView(
        children: [
          // Bascule du thème sombre/clair
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text(loc.translate('dark_mode')),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              themeNotifier.toggle();
            },
          ),
          if (_isAdmin(user))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text(loc.translate('admin_panel')),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminScreen(),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(loc.translate('logout')),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(loc.translate('language')),
            onTap: () {
              // TODO: implémenter le changement de langue
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(loc.translate('about')),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Kin‑Experience',
                applicationVersion: '1.0.0',
                children: [
                  Text('Application de guide touristique pour Kinshasa.'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(loc.translate('notifications')),
            onTap: () {
              // TODO: implémenter les paramètres de notifications
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('${loc.translate('version')} 1.0.0'),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kin_experience/views/edit_profile_screen.dart';
import 'package:kin_experience/views/favorites_screen.dart';
import 'package:kin_experience/views/settings_screen.dart';

import '../controllers/favorites_controller.dart';
import '../localization/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  Color get _headerBlue => const Color(0xFF05814C);
  Color get _pillBlue => const Color(0xFF2B3DA8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    // ✅ Favoris dynamiques via Riverpod
    final favAsync = ref.watch(favoritesControllerProvider);

    // Compteur favoris (fallback 0)
    final favCount = favAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('nav_profile')),
        centerTitle: false,
        elevation: 0,
      ),
      body: user == null
          ? _GuestView(loc: loc)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snap) {
          // Valeurs fallback (Auth)
          final authDisplayName =
          (user.displayName ?? '').trim().isNotEmpty
              ? user.displayName!.trim()
              : 'Utilisateur';
          final authEmail = user.email ?? '—';

          // Valeurs Firestore
          String firstName = '';
          String lastName = '';
          String phone = '';
          String email = '';

          if (snap.hasData && snap.data?.data() != null) {
            final data = snap.data!.data()!;
            firstName = (data['firstName'] ?? '').toString().trim();
            lastName = (data['lastName'] ?? '').toString().trim();
            phone = (data['phone'] ?? '').toString().trim();
            email = (data['email'] ?? '').toString().trim();
          }

          // Nom affiché : Firestore > displayName > "Utilisateur"
          final fullNameFromFs =
          '${firstName.isEmpty ? '' : firstName}${(firstName.isNotEmpty && lastName.isNotEmpty) ? ' ' : ''}${lastName.isEmpty ? '' : lastName}'
              .trim();

          final displayName =
          fullNameFromFs.isNotEmpty ? fullNameFromFs : authDisplayName;

          // Email affiché : Firestore > Auth
          final displayEmail = email.isNotEmpty ? email : authEmail;

          // Téléphone : Firestore > —
          final displayPhone = phone.isNotEmpty ? phone : '—';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              // =========================
              // HEADER CARD (bleu)
              // =========================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _headerBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withOpacity(0.18),
                          child: const Icon(Icons.person,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayEmail,
                                style:
                                theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayPhone,
                                style:
                                theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: Colors.white.withOpacity(0.18)),
                    const SizedBox(height: 10),

                    // Stats (Favoris dynamique)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(value: favCount.toString(), label: "Favoris"),
                        const _StatItem(value: "0", label: "Avis"),
                        // const _StatItem(value: "0", label: "Listes"),
                      ],
                    ),

                    // Optionnel: affichage chargement/erreur Firestore
                    if (snap.connectionState == ConnectionState.waiting)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Chargement du profil...",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    if (snap.hasError)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          "Erreur de chargement du profil Firestore.",
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =========================
              // PREFERENCES
              // =========================
              const _SectionLabel(title: "PRÉFÉRENCES"),
              const SizedBox(height: 8),

              // _ProfileTile(
              //   icon: Icons.notifications_none,
              //   title: "Notifications",
              //   onTap: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       const SnackBar(content: Text("Notifications (à connecter)")),
              //     );
              //   },
              // ),

              _ProfileTile(
                icon: Icons.location_on_outlined,
                title: "Localisation",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Localisation (à connecter)")),
                  );
                },
              ),

              // ✅ Mes favoris (compteur dynamique + état de chargement possible)
              favAsync.when(
                data: (_) => _ProfileTile(
                  icon: Icons.favorite_border,
                  title: "Mes favoris",
                  trailing: _CountPill(
                      value: favCount.toString(), color: _pillBlue),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),
                loading: () => _ProfileTile(
                  icon: Icons.favorite_border,
                  title: "Mes favoris",
                  trailing: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),
                error: (e, _) => _ProfileTile(
                  icon: Icons.favorite_border,
                  title: "Mes favoris",
                  trailing: const Icon(Icons.error_outline),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // =========================
              // COMPTE
              // =========================
              const _SectionLabel(title: "COMPTE"),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.person_outline,
                title: "Informations personnelles",
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );

                  // ✅ Si profil modifié → refresh (si tu as un provider, sinon juste snack)
                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profil actualisé.")),
                    );
                  }
                },
              ),


              // _ProfileTile(
              //   icon: Icons.credit_card_outlined,
              //   title: "Moyens de paiement",
              //   onTap: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       const SnackBar(content: Text("Paiement (à connecter)")),
              //     );
              //   },
              // ),

              // _ProfileTile(
              //   icon: Icons.settings_outlined,
              //   title: "Paramètres",
              //   onTap: () {
              //     onTap: () => Navigator.of(context).pushReplacement(
              //       MaterialPageRoute(builder: (_) => SettingsScreen()),
              //     );
              //   },
              // ),

              const SizedBox(height: 18),

              // =========================
              // SUPPORT
              // =========================
              const _SectionLabel(title: "SUPPORT"),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.help_outline,
                title: "Centre d'aide",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Centre d'aide (à connecter)")),
                  );
                },
              ),

              // _ProfileTile(
              //   icon: Icons.privacy_tip_outlined,
              //   title: "Confidentialité",
              //   onTap: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       const SnackBar(content: Text("Confidentialité (à connecter)")),
              //     );
              //   },
              // ),

              const SizedBox(height: 14),

              // =========================
              // DECONNEXION
              // =========================
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.15),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Déconnexion",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Déconnecté.")),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  "Version 1.0.0",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================
// UI: Guest View (non connecté)
// ==========================
class _GuestView extends StatelessWidget {
  final AppLocalizations loc;
  const _GuestView({required this.loc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 70, color: theme.dividerColor),
            const SizedBox(height: 12),
            Text(
              loc.translate('login'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// UI: Section Label
// ==========================
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
      ),
    );
  }
}

// ==========================
// UI: Tile
// ==========================
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        trailing: trailing ??
            Icon(Icons.chevron_right, color: theme.dividerColor.withOpacity(0.6)),
        onTap: onTap,
      ),
    );
  }
}

// ==========================
// UI: Stats
// ==========================
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}

// ==========================
// UI: Small pill number
// ==========================
class _CountPill extends StatelessWidget {
  final String value;
  final Color color;
  const _CountPill({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

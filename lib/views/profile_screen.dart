import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kin_experience/views/edit_profile_screen.dart';
import 'package:kin_experience/views/favorites_screen.dart';
import 'package:kin_experience/views/settings_screen.dart';

import '../controllers/favorites_controller.dart';
import '../localization/app_localizations.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Color get _headerBlue => const Color(0xFF05814C);
  Color get _pillBlue => const Color(0xFF2B3DA8);

  bool _uploadingAvatar = false;

  // -------------------------
  // Phone formatting (RDC)
  // -------------------------
  // -------------------------
  // Delete Account
  // -------------------------
  Future<void> _showDeleteAccountDialog(BuildContext context, User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Supprimer le compte',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette action est irréversible et entraînera :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• Suppression de toutes vos données'),
            const Text('• Suppression de vos favoris'),
            const Text('• Suppression de vos avis'),
            const Text('• Suppression de votre profil'),
            const SizedBox(height: 16),
            const Text(
              'Voulez-vous vraiment continuer ?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Supprimer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Second confirmation dialog
    final finalConfirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ Dernière confirmation',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Êtes-vous absolument certain de vouloir supprimer votre compte ?\n\n'
              'Cette action est IRRÉVERSIBLE.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non, conserver mon compte'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Oui, supprimer définitivement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (finalConfirmation != true) return;

    // Show loading
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Suppression en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Delete user data from Firestore
      final batch = FirebaseFirestore.instance.batch();

      // Delete user document
      batch.delete(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
      );

      // Delete favorites subcollection (if any)
      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();

      for (final doc in favoritesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete notifications subcollection (if any)
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();

      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit batch
      await batch.commit();

      // Delete reviews (where userId = user.uid)
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .get();

      final reviewsBatch = FirebaseFirestore.instance.batch();
      for (final doc in reviewsSnapshot.docs) {
        reviewsBatch.delete(doc.reference);
      }
      await reviewsBatch.commit();

      // Delete profile photo from Storage (if exists)
      try {
        final photoRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${user.uid}/avatar.jpg');
        await photoRef.delete();
      } catch (e) {
        // Photo might not exist, ignore error
        print('No profile photo to delete or error: $e');
      }

      // Delete Firebase Auth account
      await user.delete();

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Sign out (should happen automatically after delete)
      await FirebaseAuth.instance.signOut();

      // Show success message
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre compte a été supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Show error
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erreur'),
          content: Text(
            'Impossible de supprimer le compte:\n$e\n\n'
                'Essayez de vous reconnecter puis de supprimer à nouveau.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String formatRdcPhone(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '—') return '—';

    // keep digits only
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');

    // Cases:
    // - 0XXXXXXXXX (10 digits with leading 0) -> +243XXXXXXXXX
    // - 243XXXXXXXXX -> +243XXXXXXXXX
    // - already +243...
    String normalizedDigits;
    if (digits.startsWith('0') && digits.length == 10) {
      normalizedDigits = '243${digits.substring(1)}';
    } else if (digits.startsWith('243') && digits.length >= 12) {
      normalizedDigits = digits;
    } else if (digits.length == 9) {
      // sometimes stored without prefix: XXXXXXXXX
      normalizedDigits = '243$digits';
    } else {
      // fallback: return original cleaned
      return s;
    }

    // After 243, DRC mobile is typically 9 digits
    final rest = normalizedDigits.substring(3);
    if (rest.length < 9) return '+$normalizedDigits';

    final a = rest.substring(0, 2);
    final b = rest.substring(2, 5);
    final c = rest.substring(5, 9);

    return '+243 $a $b $c';
  }

  // -------------------------
  // Upload avatar to Storage + save URL in Firestore
  // -------------------------
  Future<void> _pickAndUploadAvatar(BuildContext context, User user) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // compresse un peu
      );

      if (xfile == null) return;

      setState(() => _uploadingAvatar = true);

      final file = File(xfile.path);

      // Path conseillé
      final path = 'profile_photos/${user.uid}/avatar.jpg';
      final refStorage = FirebaseStorage.instance.ref().child(path);

      // Upload
      await refStorage.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // URL publique
      final url = await refStorage.getDownloadURL();

      // Save in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'photoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo de profil mise à jour.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur upload photo: $e")),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    // ✅ Favoris dynamiques via Riverpod
    final favAsync = ref.watch(favoritesControllerProvider);

    // Compteur favoris (fallback 0)
    final favCount = favAsync. maybeWhen(
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
          String photoUrl = '';

          if (snap.hasData && snap.data?.data() != null) {
            final data = snap.data!.data()!;
            firstName = (data['firstName'] ?? '').toString().trim();
            lastName = (data['lastName'] ?? '').toString().trim();
            phone = (data['phone'] ?? '').toString().trim();
            email = (data['email'] ?? '').toString().trim();
            photoUrl = (data['photoUrl'] ?? '').toString().trim();
          }

          // Nom affiché : Firestore > displayName > "Utilisateur"
          final fullNameFromFs =
          '${firstName.isEmpty ? '' : firstName}'
              '${(firstName.isNotEmpty && lastName.isNotEmpty) ? ' ' : ''}'
              '${lastName.isEmpty ? '' : lastName}'
              .trim();

          final displayName =
          fullNameFromFs.isNotEmpty ? fullNameFromFs : authDisplayName;

          // Email affiché : Firestore > Auth
          final displayEmail = email.isNotEmpty ? email : authEmail;

          // Téléphone format RDC
          final displayPhoneRaw = phone.isNotEmpty ? phone : '—';
          final displayPhone = formatRdcPhone(displayPhoneRaw);

          // ✅ Avis synchro depuis Firestore
          final reviewsStream = FirebaseFirestore.instance
              .collection("reviews")
              .where("userId", isEqualTo: user.uid)
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: reviewsStream,
            builder: (context, reviewsSnap) {
              final reviewsCount = reviewsSnap.data?.docs.length ?? 0;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  // =========================
                  // HEADER CARD
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
                            GestureDetector(
                              onTap: _uploadingAvatar
                                  ? null
                                  : () => _pickAndUploadAvatar(context, user),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor:
                                    Colors.white.withOpacity(0.18),
                                    backgroundImage: photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl.isEmpty
                                        ? const Icon(Icons.person,
                                        color: Colors.white)
                                        : null,
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      shape: BoxShape.circle,
                                    ),
                                    child: _uploadingAvatar
                                        ? const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
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
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayPhone,
                                    style: theme.textTheme.bodySmall?.copyWith(
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StatItem(
                                value: favCount.toString(), label: "Favoris"),
                            _StatItem(
                                value: reviewsCount.toString(), label: "Avis"),
                          ],
                        ),

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

                  favAsync.when(
                    data: (_) => _ProfileTile(
                      icon: Icons.favorite_border,
                      title: "Mes favoris",
                      trailing: _CountPill(
                          value: favCount.toString(), color: _pillBlue),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FavoritesScreen()),
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
                          MaterialPageRoute(
                              builder: (_) => const FavoritesScreen()),
                        );
                      },
                    ),
                    error: (e, _) => _ProfileTile(
                      icon: Icons.favorite_border,
                      title: "Mes favoris",
                      trailing: const Icon(Icons.error_outline),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FavoritesScreen()),
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
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      );

                      if (result == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Profil actualisé.")),
                        );
                      }
                    },
                  ),

                  _ProfileTile(
                    icon: Icons.settings_outlined,
                    title: "Paramètres",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),

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
                        const SnackBar(
                            content: Text("Centre d'aide (à connecter)")),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ProfileTile(
                    icon: Icons.lock,
                    title: "Politique de Confidentialité",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("+243810241596")),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // =========================
                  // SUPPRESSION DE COMPTE
                  // =========================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        "Supprimer mon compte",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        "Action irréversible",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await _showDeleteAccountDialog(context, user);
                        }
                      },
                    ),
                  ),

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
                        color: theme.textTheme.bodySmall?.color
                            ?.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              );
            },
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
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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
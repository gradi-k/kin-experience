import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/place_enums.dart';
import '../views/auth_screen.dart';

/// AdminScreen
/// - Tableau de bord (style "profil") pour gérer les contenus.
/// - Affiche des compteurs (Publiés / Brouillons)
/// - Menu d'actions : Ajouter contenu, Liste contenus, Brouillons, Ajouter reel, Liste reels
/// - Avatar en haut à droite (hors bande verte) avec menu "Déconnexion"
class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Couleur principale (proche de la capture)
  static const Color _green = Color(0xFF0B7A4A);

  // Pour éviter plusieurs clics simultanés sur déconnexion
  bool _signingOut = false;

  late final Future<_AdminCounts> _countsFuture = _loadCounts();

  // ---------------------------
  // Data: compute published/drafts
  // ---------------------------
  Future<_AdminCounts> _loadCounts() async {
    int published = 0;
    int drafts = 0;

    // Hypothèse: vous stockez vos contenus par catégorie dans des collections distinctes.
    // Si vous utilisez une autre structure, adaptez ici.
    final categories = PlaceCategory.values;

    for (final c in categories) {
      final collection = _collectionName(c);
      final snap = await FirebaseFirestore.instance.collection(collection).get();

      for (final d in snap.docs) {
        final data = d.data();

        // Heuristique robuste : plusieurs noms possibles pour le statut brouillon
        final dynamic isDraft =
            data['isDraft'] ?? data['draft'] ?? (data['status'] == 'draft');

        if (isDraft == true) {
          drafts += 1;
        } else {
          published += 1;
        }
      }
    }

    return _AdminCounts(published: published, drafts: drafts);
  }

  // IMPORTANT: centraliser le mapping de collection
  // (évite les erreurs "getter collectionName not defined" et les extensions ambiguës)
  String _collectionName(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.resto:
        return 'restaurants';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'business';
      case PlaceCategory.shopping:
      default:
        return 'other';
        return 'shopping';
    }
  }

  // ---------------------------
  // Navigation placeholders (à brancher sur vos vraies pages)
  // ---------------------------
  void _openAddContent() {
    _toast('Ouvrir : Ajouter un contenue (à brancher)');
  }

  void _openContentList() {
    _toast('Ouvrir : Liste des contenues (à brancher)');
  }

  void _openDrafts() {
    _toast('Ouvrir : Brouillons (à brancher)');
  }

  void _openAddReel() {
    _toast('Ouvrir : Ajouter un reel (à brancher)');
  }

  void _openReelsList() {
    _toast('Ouvrir : Liste des reels (à brancher)');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---------------------------
  // Logout
  // ---------------------------
  Future<void> _signOut() async {
    if (_signingOut) return;

    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Même si signOut échoue, on force le retour sur Auth
    } finally {
      if (!mounted) return;
      setState(() => _signingOut = false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu principal (scroll)
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                const SizedBox(height: 46),
                _headerTitle(theme),
                const SizedBox(height: 14),

                // Bande verte + stats
                FutureBuilder<_AdminCounts>(
                  future: _countsFuture,
                  builder: (context, snap) {
                    final published = snap.data?.published ?? 0;
                    final drafts = snap.data?.drafts ?? 0;
                    return _statsCard(theme, published: published, drafts: drafts);
                  },
                ),

                const SizedBox(height: 16),

                // Actions
                _sectionLabel(theme, 'GESTION'),
                const SizedBox(height: 10),

                _menuButton(
                  theme,
                  icon: Icons.add_circle_outline,
                  label: 'Ajouter un contenue',
                  onTap: _openAddContent,
                ),
                _menuButton(
                  theme,
                  icon: Icons.list_alt_outlined,
                  label: 'Liste des contenues',
                  onTap: _openContentList,
                  badge: null,
                ),
                _menuButton(
                  theme,
                  icon: Icons.feed_outlined,
                  label: 'Brouillons',
                  onTap: _openDrafts,
                ),
                const SizedBox(height: 6),

                _sectionLabel(theme, 'REELS'),
                const SizedBox(height: 10),

                _menuButton(
                  theme,
                  icon: Icons.video_call_outlined,
                  label: 'Ajouter un reel',
                  onTap: _openAddReel,
                ),
                _menuButton(
                  theme,
                  icon: Icons.playlist_play_outlined,
                  label: 'Liste des reels',
                  onTap: _openReelsList,
                ),
                _sectionLabel(theme, 'PUBLICITES'),
                const SizedBox(height: 10),

                _menuButton(
                  theme,
                  icon: Icons.add_circle_outline,
                  label: 'Ajouter une Pub',
                  onTap: _openAddReel,
                ),
                _menuButton(
                  theme,
                  icon: Icons.list_alt_outlined,
                  label: 'Liste des publicites',
                  onTap: _openReelsList,
                ),
              ],
            ),

            // Avatar en haut à droite (hors bande verte)
            Positioned(
              top: 10,
              right: 16,
              child: _profileMenu(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerTitle(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.admin_panel_settings_outlined, color: theme.textTheme.titleLarge?.color),
        const SizedBox(width: 10),
        Text(
          'Administration',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _statsCard(ThemeData theme, {required int published, required int drafts}) {
    final textColor = Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              theme,
              value: published.toString(),
              label: 'Publiés',
              textColor: textColor,
              icon: Icons.public,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withOpacity(0.28),
          ),
          Expanded(
            child: _statItem(
              theme,
              value: drafts.toString(),
              label: 'Brouillons',
              textColor: textColor,
              icon: Icons.feed_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      ThemeData theme, {
        required String value,
        required String label,
        required Color textColor,
        required IconData icon,
      }) {
    return Row(
      children: [
        Icon(icon, color: textColor.withOpacity(0.95), size: 22),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withOpacity(0.90),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
      ),
    );
  }

  Widget _menuButton(
      ThemeData theme, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        int? badge,
      }) {
    final bg = theme.brightness == Brightness.light ? Colors.white : theme.cardColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.20),
        ),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _green.withOpacity(0.10),
          child: Icon(icon, color: _green),
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  Widget _profileMenu(ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();

    return PopupMenuButton<String>(
      tooltip: 'Compte',
      onSelected: (v) {
        if (v == 'logout') _signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Déconnexion'),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: _green,
              backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          // Mini infos (optionnel)
          if ((displayName != null && displayName.isNotEmpty) ||
              (email != null && email.isNotEmpty))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? Colors.white.withOpacity(0.92)
                    : theme.cardColor.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (displayName != null && displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  if (email != null && email.isNotEmpty)
                    Text(
                      email,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminCounts {
  final int published;
  final int drafts;

  const _AdminCounts({required this.published, required this.drafts});
}
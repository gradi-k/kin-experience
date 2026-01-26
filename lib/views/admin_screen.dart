// lib/views/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin/ads/add_ad_form.dart';
import 'admin/ads/ads_list_screen.dart';
import 'admin/contents/add_content_form.dart';
import 'admin/reels/add_reel_form.dart';
import 'admin/contents/content_list_screen.dart';
import 'admin/contents/drafts_screen.dart';
import '../models/place_enums.dart';
import 'admin/reels/reels_list_screen.dart';
import '../main.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const Color _green = Color(0xFF0B7A4A);
  bool _signingOut = false;
  Future<_AdminCounts>? _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
  }

  Future<_AdminCounts> _loadCounts() async {
    int published = 0;
    int drafts = 0;

    for (final c in PlaceCategory.values) {
      final collection = _collectionName(c);
      try {
        final snap = await FirebaseFirestore.instance.collection(collection).get();
        for (final d in snap.docs) {
          final data = d.data();
          final dynamic isDraft = data['isDraft'] ?? data['draft'] ?? (data['status'] == 'draft');
          if (isDraft == true) {
            drafts += 1;
          } else {
            published += 1;
          }
        }
      } catch (e) {
        print('❌ Error loading $collection: $e');
      }
    }

    return _AdminCounts(published: published, drafts: drafts);
  }

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
        return 'business';  // ✅ CHANGÉ : Correspond à Firestore
      case PlaceCategory.shopping:
        return 'shopping';  // ✅ CHANGÉ : Correspond à Firestore
    }
  }

  // ✅ CORRECTION 1 : setState ne doit PAS retourner un Future
  void _refreshCounts() {
    setState(() {
      _countsFuture = _loadCounts();
    });
  }

  void _openAddContent() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategorySelector(
        onCategorySelected: (category) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddContentForm(category: category)),
          ).then((_) => _refreshCounts());  // ✅ CORRIGÉ : Pas de Future dans setState
        },
      ),
    );
  }

  void _openContentList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategorySelector(
        onCategorySelected: (category) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContentListScreen(category: category)),
          ).then((_) => _refreshCounts());  // ✅ CORRIGÉ : Pas de Future dans setState
        },
      ),
    );
  }

  void _openDrafts() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DraftsScreen()))
        .then((_) => _refreshCounts());  // ✅ CORRIGÉ : Pas de Future dans setState
  }

  void _openAddReel() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddReelForm()));
  }

  void _openReelsList() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReelsListScreen()));
  }

  void _openAddAd(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddAdForm()));
  }

  void _openAdsList(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdsListScreen()));
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                const SizedBox(height: 46),
                _headerTitle(theme),
                const SizedBox(height: 14),
                FutureBuilder<_AdminCounts>(
                  future: _countsFuture,
                  builder: (context, snap) {
                    final published = snap.data?.published ?? 0;
                    final drafts = snap.data?.drafts ?? 0;
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('reels')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, reelsSnap) {
                        final reels = reelsSnap.hasData ? reelsSnap.data!.docs.length : 0;
                        return _statsCard(theme, published: published, drafts: drafts, reels: reels);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _sectionLabel(theme, 'GESTION'),
                const SizedBox(height: 10),
                _menuButton(theme, icon: Icons.add_circle_outline, label: 'Ajouter un contenu', onTap: _openAddContent),
                _menuButton(theme, icon: Icons.list_alt_outlined, label: 'Liste des contenus', onTap: _openContentList),
                _menuButton(theme, icon: Icons.feed_outlined, label: 'Brouillons', onTap: _openDrafts),
                const SizedBox(height: 6),
                _sectionLabel(theme, 'REELS'),
                const SizedBox(height: 10),
                _menuButton(theme, icon: Icons.video_call_outlined, label: 'Ajouter un reel', onTap: _openAddReel),
                _menuButton(theme, icon: Icons.playlist_play_outlined, label: 'Liste des reels', onTap: _openReelsList),
                const SizedBox(height: 6),
                _sectionLabel(theme, 'PUBLICITES'),
                const SizedBox(height: 10),
                _menuButton(theme, icon: Icons.add_circle_outline, label: 'Ajouter une Pub', onTap: () => _openAddAd(context)),
                _menuButton(theme, icon: Icons.list_alt_outlined, label: 'Liste des publicites', onTap: () => _openAdsList(context)),
              ],
            ),
            Positioned(top: 10, right: 10, child: _profileMenu(theme)),
          ],
        ),
      ),
    );
  }

  Widget _headerTitle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tableau de bord',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gerez le contenu de Kin City Guide',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _statsCard(ThemeData theme, {required int published, required int drafts, required int reels}) {
    const textColor = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7A4A), Color(0xFF1DAE71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B7A4A).withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(theme, value: published.toString(), label: 'Publiés', textColor: textColor, icon: Icons.check_circle_outline),
          ),
          _divider(),
          Expanded(
            child: _statItem(theme, value: drafts.toString(), label: 'Brouillons', textColor: textColor, icon: Icons.drafts_outlined),
          ),
          _divider(),
          Expanded(
            child: _statItem(theme, value: reels.toString(), label: 'Reels', textColor: textColor, icon: Icons.play_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 44,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white.withOpacity(0.28),
  );

  Widget _statItem(ThemeData theme, {required String value, required String label, required Color textColor, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: textColor.withOpacity(0.95), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
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
                  fontSize: 11,
                ),
              ),
            ],
          ),
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

  Widget _menuButton(ThemeData theme, {required IconData icon, required String label, required VoidCallback onTap, int? badge}) {
    final bg = theme.brightness == Brightness.light ? Colors.white : theme.cardColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.20)),
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
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Deconnexion'),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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

class _CategorySelector extends StatelessWidget {
  final Function(PlaceCategory) onCategorySelected;

  const _CategorySelector({required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisir une categorie',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...PlaceCategory.values.map(
                (category) => ListTile(
              leading: Icon(category.icon),
              title: Text(category.label),
              onTap: () => onCategorySelected(category),
              trailing: const Icon(Icons.chevron_right),
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
// lib/views/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads/add_ad_form.dart';
import 'ads/ads_list_screen.dart';
import 'categories/categories_list_screen.dart';
import 'contents/add_content_form.dart';
import 'reels/add_reel_form.dart';
import 'contents/content_list_screen.dart';
import 'contents/drafts_screen.dart';
import 'imports/apify_imports_screen.dart';
import '../../controllers/categories_controller.dart';
import '../../models/category_config.dart';
import 'reels/reels_list_screen.dart';
import '../../main.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  static const Color _green = Color(0xFF0B7A4A);
  bool _signingOut = false;
  Future<_AdminCounts>? _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
  }

  /// Compte les lieux publiés et les brouillons.
  ///
  /// Deux requêtes `count()` sur `places` remplacent la lecture intégrale des
  /// 6 collections : le coût ne dépend plus du nombre de documents.
  Future<_AdminCounts> _loadCounts() async {
    final places = FirebaseFirestore.instance.collection('places');

    try {
      final results = await Future.wait([
        places.where('isDraft', isNotEqualTo: true).count().get(),
        places.where('isDraft', isEqualTo: true).count().get(),
      ]);

      return _AdminCounts(
        published: results[0].count ?? 0,
        drafts: results[1].count ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Erreur de comptage : $e');
      return const _AdminCounts(published: 0, drafts: 0);
    }
  }

  void _openCategories() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CategoriesListScreen()))
        .then((_) => _refreshCounts());
  }

  // ✅ CORRECTION 1 : setState ne doit PAS retourner un Future
  void _refreshCounts() {
    setState(() {
      if (!mounted) return;
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

  void _openApifyImports() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ApifyImportsScreen()))
        .then((_) => _refreshCounts());
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
    // Largeur max du contenu pour grands écrans
    const double maxContentWidth = 720;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > maxContentWidth
                ? (constraints.maxWidth - maxContentWidth) / 2
                : 16.0;

            return Column(
              children: [
                // ── En-tête fixe (hors scroll) ─────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 10, horizontalPadding, 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _headerTitle(theme)),
                      const SizedBox(width: 12),
                      _profileMenu(theme),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ── Contenu scrollable ──────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, 24,
                    ),
                    children: [
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
                              final reels = reelsSnap.hasData
                                  ? reelsSnap.data!.docs.length
                                  : 0;
                              return _statsCard(
                                theme,
                                published: published,
                                drafts: drafts,
                                reels: reels,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(theme, 'GESTION'),
                      const SizedBox(height: 10),
                      _menuButton(theme, icon: Icons.add_circle_outline, label: 'Ajouter un contenu', onTap: _openAddContent),
                      _menuButton(theme, icon: Icons.list_alt_outlined, label: 'Liste des contenus', onTap: _openContentList),
                      _menuButton(theme, icon: Icons.feed_outlined, label: 'Brouillons', onTap: _openDrafts),
                      _menuButton(
                        theme,
                        icon: Icons.category_outlined,
                        label: 'Catégories',
                        onTap: _openCategories,
                        badge: ref.watch(allCategoriesProvider).value?.length,
                      ),
                      const SizedBox(height: 10),
                      _sectionLabel(theme, 'REELS'),
                      const SizedBox(height: 10),
                      _menuButton(theme, icon: Icons.video_call_outlined, label: 'Ajouter un reel', onTap: _openAddReel),
                      _menuButton(theme, icon: Icons.playlist_play_outlined, label: 'Liste des reels', onTap: _openReelsList),
                      const SizedBox(height: 10),
                      _sectionLabel(theme, 'PUBLICITES'),
                      const SizedBox(height: 10),
                      _menuButton(theme, icon: Icons.add_circle_outline, label: 'Ajouter une Pub', onTap: () => _openAddAd(context)),
                      _menuButton(theme, icon: Icons.list_alt_outlined, label: 'Liste des publicites', onTap: () => _openAdsList(context)),
                      const SizedBox(height: 10),
                      _sectionLabel(theme, 'IMPORTS'),
                      const SizedBox(height: 10),
                      _menuButton(theme, icon: Icons.cloud_download_outlined, label: 'Imports Apify', onTap: _openApifyImports),
                    ],
                  ),
                ),
              ],
            );
          },
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
          'Gerez le contenu de City Guide',
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
            child: _statItem(theme, value: drafts.toString(), label: 'Brouillons', textColor: textColor, icon: Icons.feed_outlined),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((displayName != null && displayName.isNotEmpty) ||
              (email != null && email.isNotEmpty))
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Container(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (displayName != null && displayName.isNotEmpty)
                      Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    if (email != null && email.isNotEmpty)
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.70),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

/// Sélection de la catégorie avant d'ajouter ou de lister un contenu.
///
/// Alimenté par `categories` : la liste suit ce qui est configuré, y compris
/// les catégories désactivées — un admin doit pouvoir gérer le contenu d'une
/// catégorie masquée au public.
class _CategorySelector extends ConsumerWidget {
  final void Function(CategoryConfig) onCategorySelected;

  const _CategorySelector({required this.onCategorySelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisir une catégorie',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur : $e'),
              data: (categories) {
                if (categories.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aucune catégorie configurée. Créez-en une depuis '
                      '« Catégories ».',
                    ),
                  );
                }

                return ListView(
                  shrinkWrap: true,
                  children: categories
                      .map(
                        (category) => ListTile(
                          leading: Icon(
                            category.icon,
                            color: category.enabled ? null : theme.disabledColor,
                          ),
                          title: Text(category.labelFor('fr')),
                          subtitle:
                              category.enabled ? null : const Text('Masquée'),
                          onTap: () => onCategorySelected(category),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      )
                      .toList(),
                );
              },
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
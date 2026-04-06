// lib/views/reels_list_screen.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cityguide/models/reel.dart';
import 'package:cityguide/views/admin/reels/add_reel_form.dart';
import 'package:cityguide/views/reels/reels_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';



/// Écran de gestion des reels pour l'admin
class ReelsListScreen extends StatefulWidget {
  const ReelsListScreen({super.key});

  @override
  State<ReelsListScreen> createState() => _ReelsListScreenState();
}

class _ReelsListScreenState extends State<ReelsListScreen> {
  static const Color _green = Color(0xFF0B7A4A);

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Supprimer un reel
  Future<void> _deleteReel(String id, String reelName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce reel ?'),
        content: Text('Voulez-vous vraiment supprimer "$reelName" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reels').doc(id).delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel supprimé avec succès'),
            backgroundColor: _green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Toggle le statut actif/inactif
  Future<void> _toggleActive(String id, bool currentValue) async {
    try {
      await FirebaseFirestore.instance.collection('reels').doc(id).update({
        'isActive': !currentValue,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Ouvrir le reel en plein écran
  void _openReel(String reelId, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelsScreen(
          initialReelId: reelId,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestion des Reels'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filtres
          PopupMenuButton<String>(
            icon: Icon(
              _filterStatus == 'all'
                  ? Icons.filter_list
                  : _filterStatus == 'active'
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: _filterStatus != 'all' ? Colors.amber : null,
            ),
            tooltip: 'Filtrer',
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: _filterStatus == 'all' ? _green : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Tous les reels'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'active',
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      color: _filterStatus == 'active' ? _green : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Actifs uniquement'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'inactive',
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: _filterStatus == 'inactive' ? _green : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Inactifs uniquement'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddReelForm()),
          );
          if (result == true && mounted) {
            setState(() {});
          }
        },
        backgroundColor: _green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Reel', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: _green,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un reel...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Liste des reels
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reels')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                // Appliquer les filtres
                if (_filterStatus == 'active') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['isActive'] == true;
                  }).toList();
                } else if (_filterStatus == 'inactive') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['isActive'] != true;
                  }).toList();
                }

                // Appliquer la recherche
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final caption = (data['caption'] ?? '').toString().toLowerCase();
                    final location = (data['location'] ?? '').toString().toLowerCase();
                    final author = (data['authorName'] ?? '').toString().toLowerCase();
                    return caption.contains(_searchQuery) ||
                        location.contains(_searchQuery) ||
                        author.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Aucun résultat'
                              : _filterStatus == 'active'
                              ? 'Aucun reel actif'
                              : _filterStatus == 'inactive'
                              ? 'Aucun reel inactif'
                              : 'Aucun reel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final reel = Reel.fromFirestore(doc);

                    return _ReelCard(
                      reel: reel,
                      index: index,
                      onEdit: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddReelForm(existingReel: reel),
                          ),
                        );
                        if (result == true && mounted) {
                          setState(() {});
                        }
                      },
                      onDelete: () => _deleteReel(reel.id, reel.caption),
                      onToggleActive: () => _toggleActive(reel.id, reel.isActive),
                      onView: () => _openReel(reel.id, index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Card d'un reel
class _ReelCard extends StatelessWidget {
  static const Color _green = Color(0xFF0B7A4A);

  final Reel reel;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onView;

  const _ReelCard({
    required this.reel,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail et infos
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail vidéo avec preview
                _VideoThumbnail(
                  videoUrl: reel.videoUrl,
                  onTap: onView,
                ),

                // Infos
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statut et badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusBadge(
                              label: reel.isActive ? 'Actif' : 'Inactif',
                              color: reel.isActive ? _green : Colors.orange,
                              icon: reel.isActive
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            if (reel.hasLinkedPlace)
                              _StatusBadge(
                                label: 'Lieu lié',
                                color: Colors.blue,
                                icon: Icons.place,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Caption
                        Text(
                          reel.caption.isNotEmpty ? reel.caption : '(Sans légende)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Auteur
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reel.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Location
                        if (reel.location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.place, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  reel.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const Spacer(),

                        // Date
                        Text(
                          _formatDate(reel.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats et actions
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Stats
                _StatChip(icon: Icons.favorite, value: '${reel.likes}'),
                const SizedBox(width: 12),
                _StatChip(icon: Icons.chat_bubble, value: '${reel.comments}'),

                const Spacer(),

                // Actions
                IconButton(
                  icon: Icon(
                    reel.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: reel.isActive ? Colors.grey.shade600 : Colors.orange,
                  ),
                  tooltip: reel.isActive ? 'Désactiver' : 'Activer',
                  onPressed: onToggleActive,
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: _green),
                  tooltip: 'Modifier',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date inconnue';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'Il y a ${diff.inDays ~/ 7} semaines';
    if (diff.inDays < 365) return 'Il y a ${diff.inDays ~/ 30} mois';
    return 'Il y a ${diff.inDays ~/ 365} ans';
  }
}

/// Thumbnail de vidéo avec preview
class _VideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final VoidCallback onTap;

  const _VideoThumbnail({
    required this.videoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Ouvrir le dialog de preview
        showDialog(
          context: context,
          builder: (context) => _VideoPreviewDialog(videoUrl: videoUrl),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: SizedBox(
          width: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail généré
              FutureBuilder<Uint8List?>(
                future: VideoThumbnail.thumbnailData(
                  video: videoUrl,
                  imageFormat: ImageFormat.JPEG,
                  maxWidth: 120,
                  quality: 50,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }

                  return Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),

              // Play button
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),

              // Gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog de preview vidéo
class _VideoPreviewDialog extends StatefulWidget {
  final String videoUrl;

  const _VideoPreviewDialog({required this.videoUrl});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = widget.videoUrl.startsWith('assets/')
          ? VideoPlayerController.asset(widget.videoUrl)
          : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aperçu vidéo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Video player
                if (_hasError)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.white54),
                        const SizedBox(height: 16),
                        const Text(
                          'Impossible de charger la vidéo',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isInitialized = false;
                            });
                            _initializeVideo();
                          },
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                else if (!_isInitialized)
                  const Padding(
                    padding: EdgeInsets.all(64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Chargement...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        AnimatedOpacity(
                          opacity: _isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Progress bar
                if (_isInitialized && !_hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF0B7A4A),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),

                // Controls
                if (_isInitialized && !_hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            _controller.value.volume > 0
                                ? Icons.volume_up
                                : Icons.volume_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.setVolume(
                                _controller.value.volume > 0 ? 0.0 : 1.0,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),);
    }
}

/// Badge de statut
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de statistique
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
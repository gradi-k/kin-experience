// lib/views/reels_screen.dart

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cityguide/views/home_screen.dart';
import 'package:cityguide/views/reels/widgets/reel_place_sheet.dart';
import 'package:video_player/video_player.dart';

import '../../models/reel.dart';

class ReelsScreen extends StatefulWidget {
  final int initialIndex;
  final String? initialReelId;

  const ReelsScreen({
    super.key,
    this.initialIndex = 0,
    this.initialReelId,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  PageController? _pageController;

  List<Reel> _reels = [];
  bool _isLoadingReels = true;
  String? _error;

  final Map<int, VideoPlayerController> _controllers = {};
  int _currentIndex = 0;

  bool _isChangingPage = false;
  bool _isVideoLoading = false;
  bool _muted = false;
  bool _showControls = false;
  double _playbackSpeed = 1.0;

  bool _disposed = false;
  Timer? _hideControlsTimer;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, bool> _userLikes = {};
  Map<String, int> _likesCount = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _loadReels();
  }

  @override
  void dispose() {
    _disposed = true;
    _hideControlsTimer?.cancel();

    for (final controller in _controllers.values) {
      _safeDisposeController(controller);
    }
    _controllers.clear();

    _pageController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadReels() async {
    try {
      final snapshot = await _firestore
          .collection('reels')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (_disposed) return;

      final reels = snapshot.docs.map((doc) => Reel.fromFirestore(doc)).toList();

      if (!mounted) return;

      for (var reel in reels) {
        _likesCount[reel.id] = reel.likes;
      }

      setState(() {
        _reels = reels;
        _isLoadingReels = false;
      });

      if (_reels.isNotEmpty) {
        int startIndex = widget.initialIndex.clamp(0, _reels.length - 1);

        if (widget.initialReelId != null) {
          final idx = _reels.indexWhere((r) => r.id == widget.initialReelId);
          if (idx >= 0) startIndex = idx;
        }

        _pageController = PageController(initialPage: startIndex);
        _currentIndex = startIndex;

        // Non bloquant : la vidéo démarre sans attendre l'état des likes
        _loadUserLikes();
        await _initializeVideoAtIndex(startIndex);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement: $e';
        _isLoadingReels = false;
      });
    }
  }

  Future<void> _loadUserLikes() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Lectures en parallèle (au lieu de N allers-retours séquentiels)
    await Future.wait(_reels.map((reel) async {
      try {
        final likeDoc = await _firestore
            .collection('reels')
            .doc(reel.id)
            .collection('likes')
            .doc(user.uid)
            .get();

        if (!_disposed) {
          _userLikes[reel.id] = likeDoc.exists;
        }
      } catch (_) {}
    }));

    if (mounted && !_disposed) setState(() {});
  }

  Future<void> _initializeVideoAtIndex(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;

    final reel = _reels[index];

    setState(() {
      _isVideoLoading = true;
    });

    try {
      if (_controllers.containsKey(index)) {
        final existingController = _controllers[index]!;
        try {
          if (existingController.value.isInitialized) {
            await existingController.setLooping(true);
            await existingController.setVolume(_muted ? 0.0 : 1.0);
            await existingController.setPlaybackSpeed(_playbackSpeed);
            await existingController.seekTo(Duration.zero);
            await existingController.play();

            if (mounted && !_disposed) {
              setState(() => _isVideoLoading = false);
            }
            return;
          }
        } catch (e) {
          _controllers.remove(index);
        }
      }

      final controller = reel.videoUrl.startsWith('assets/')
          ? VideoPlayerController.asset(reel.videoUrl)
          : VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl));

      await controller.initialize();

      if (_disposed) {
        await controller.dispose();
        return;
      }

      _controllers[index] = controller;

      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0.0 : 1.0);
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.play();

      if (mounted && !_disposed) {
        setState(() => _isVideoLoading = false);
      }

      _preloadVideoAtIndex(index + 1);

    } catch (e) {
      if (mounted && !_disposed) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _preloadVideoAtIndex(int index) async {
    if (_disposed || index < 0 || index >= _reels.length) return;
    if (_controllers.containsKey(index)) return;

    final reel = _reels[index];

    try {
      final controller = reel.videoUrl.startsWith('assets/')
          ? VideoPlayerController.asset(reel.videoUrl)
          : VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl));

      await controller.initialize();

      if (!_disposed) {
        _controllers[index] = controller;
      } else {
        await controller.dispose();
      }
    } catch (e) {}
  }

  Future<void> _safeDisposeController(VideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.pause();
      await controller.dispose();
    } catch (_) {}
  }

  void _onPageChanged(int index) async {
    if (_disposed || _isChangingPage) return;

    setState(() {
      _isChangingPage = true;
      _isVideoLoading = true;
    });

    if (_controllers.containsKey(_currentIndex)) {
      try {
        await _controllers[_currentIndex]?.pause();
      } catch (_) {}
    }

    _currentIndex = index;

    _cleanupControllers(index);

    await _initializeVideoAtIndex(index);

    if (mounted && !_disposed) {
      setState(() {
        _isChangingPage = false;
      });
    }
  }

  void _cleanupControllers(int currentIndex) {
    final keysToRemove = <int>[];

    for (final key in _controllers.keys) {
      if ((key - currentIndex).abs() > 2) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      final controller = _controllers.remove(key);
      _safeDisposeController(controller);
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_controllers.containsKey(_currentIndex)) {
      try {
        _controllers[_currentIndex]?.setVolume(_muted ? 0.0 : 1.0);
      } catch (_) {}
    }
  }

  Future<void> _toggleLike(Reel reel) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour liker')),
      );
      return;
    }

    final likeRef = _firestore
        .collection('reels')
        .doc(reel.id)
        .collection('likes')
        .doc(user.uid);

    final isLiked = _userLikes[reel.id] ?? false;
    final currentLikes = _likesCount[reel.id] ?? reel.likes;

    setState(() {
      _userLikes[reel.id] = !isLiked;
      if (isLiked) {
        _likesCount[reel.id] = (currentLikes - 1).clamp(0, 999999999);
      } else {
        _likesCount[reel.id] = currentLikes + 1;
      }
    });

    try {
      if (isLiked) {
        await likeRef.delete();
        await _firestore.collection('reels').doc(reel.id).update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        await likeRef.set({
          'userId': user.uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('reels').doc(reel.id).update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userLikes[reel.id] = isLiked;
          _likesCount[reel.id] = currentLikes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareReel(Reel reel) async {
    final parts = <String>[
      if (reel.caption.trim().isNotEmpty) reel.caption.trim(),
      if ((reel.placeName ?? '').trim().isNotEmpty)
        '📍 ${reel.placeName!.trim()}',
      if (reel.location.trim().isNotEmpty) reel.location.trim(),
      'Découvrez ce lieu sur Kin Experience !',
      reel.videoUrl,
    ];
    try {
      await Share.share(parts.join('\n'));
    } catch (_) {}
  }

  void _showComments(Reel reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(
        reelId: reel.id,
        onCommentAdded: () {
          final index = _reels.indexWhere((r) => r.id == reel.id);
          if (index >= 0 && mounted) {
            setState(() {
              _reels[index] = reel.copyWith(comments: reel.comments + 1);
            });
          }
        },
      ),
    );
  }

  void _togglePlayPause() {
    if (!_controllers.containsKey(_currentIndex)) return;

    final controller = _controllers[_currentIndex];
    if (controller == null) return;

    try {
      if (!controller.value.isInitialized) return;

      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      setState(() {});
    } catch (_) {}
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vitesse de lecture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x'),
              value: speed,
              groupValue: _playbackSpeed,
              activeColor: const Color(0xFF0B7A4A),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _playbackSpeed = value);
                  try {
                    _controllers[_currentIndex]?.setPlaybackSpeed(value);
                  } catch (_) {}
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _navigateToPlace(Reel reel) {
    if (!reel.hasLinkedPlace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun lieu lié à ce reel')),
      );
      return;
    }

    ReelPlaceSheet.show(
      context,
      placeId: reel.placeId!,
      fallbackName: reel.placeName ?? reel.location,
    );
  }

  void _exitToHome() {
    try {
      _controllers[_currentIndex]?.pause();
    } catch (_) {}

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingReels) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null && _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoadingReels = true;
                  });
                  _loadReels();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _exitToHome,
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text('Aucun reel disponible', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    if (_pageController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(color: Colors.black),

          GestureDetector(
            onTap: _handleTap,
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _reels.length,
              itemBuilder: (context, index) {
                final reel = _reels[index];
                final isCurrentPage = index == _currentIndex;
                final isLiked = _userLikes[reel.id] ?? false;
                final likesCount = _likesCount[reel.id] ?? reel.likes;

                VideoPlayerController? controller;
                bool isControllerReady = false;

                if (_controllers.containsKey(index)) {
                  try {
                    controller = _controllers[index];
                    isControllerReady = controller != null && controller.value.isInitialized;
                  } catch (_) {
                    isControllerReady = false;
                  }
                }

                return _ReelPage(
                  reel: reel,
                  controller: isCurrentPage && isControllerReady ? controller : null,
                  isLoading: isCurrentPage && (_isVideoLoading || _isChangingPage || !isControllerReady),
                  isMuted: _muted,
                  showControls: _showControls,
                  playbackSpeed: _playbackSpeed,
                  isLiked: isLiked,
                  likesCount: likesCount,
                  onToggleMute: _toggleMute,
                  onToggleLike: () => _toggleLike(reel),
                  onShowComments: () => _showComments(reel),
                  onShare: () => _shareReel(reel),
                  onShowSpeed: _showSpeedDialog,
                  onTogglePlayPause: _togglePlayPause,
                  onNavigateToPlace: () => _navigateToPlace(reel),
                );
              },
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_outlined, color: Colors.white, size: 28),
              onPressed: _exitToHome,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  final Reel reel;
  final VideoPlayerController? controller;
  final bool isLoading;
  final bool isMuted;
  final bool showControls;
  final double playbackSpeed;
  final bool isLiked;
  final int likesCount;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLike;
  final VoidCallback onShowComments;
  final VoidCallback onShare;
  final VoidCallback onShowSpeed;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNavigateToPlace;

  const _ReelPage({
    required this.reel,
    required this.controller,
    required this.isLoading,
    required this.isMuted,
    required this.showControls,
    required this.playbackSpeed,
    required this.isLiked,
    required this.likesCount,
    required this.onToggleMute,
    required this.onToggleLike,
    required this.onShowComments,
    required this.onShare,
    required this.onShowSpeed,
    required this.onTogglePlayPause,
    required this.onNavigateToPlace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),

        if (controller != null && !isLoading)
          Center(
            child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: VideoPlayer(controller!),
            ),
          ),

        if (isLoading)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Chargement...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        if (controller != null && !isLoading)
          _ReelOverlay(
            reel: reel,
            controller: controller!,
            isMuted: isMuted,
            showControls: showControls,
            playbackSpeed: playbackSpeed,
            isLiked: isLiked,
            likesCount: likesCount,
            onToggleMute: onToggleMute,
            onToggleLike: onToggleLike,
            onShowComments: onShowComments,
            onShare: onShare,
            onShowSpeed: onShowSpeed,
            onTogglePlayPause: onTogglePlayPause,
            onNavigateToPlace: onNavigateToPlace,
          ),
      ],
    );
  }
}

class _ReelOverlay extends StatelessWidget {
  final Reel reel;
  final VideoPlayerController controller;
  final bool isMuted;
  final bool showControls;
  final double playbackSpeed;
  final bool isLiked;
  final int likesCount;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLike;
  final VoidCallback onShowComments;
  final VoidCallback onShare;
  final VoidCallback onShowSpeed;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNavigateToPlace;

  const _ReelOverlay({
    required this.reel,
    required this.controller,
    required this.isMuted,
    required this.showControls,
    required this.playbackSpeed,
    required this.isLiked,
    required this.likesCount,
    required this.onToggleMute,
    required this.onToggleLike,
    required this.onShowComments,
    required this.onShare,
    required this.onShowSpeed,
    required this.onTogglePlayPause,
    required this.onNavigateToPlace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        Positioned(
          left: 16,
          right: 80,
          bottom: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // CircleAvatar(
                  //   radius: 20,
                  //   backgroundImage: reel.authorAvatar.isNotEmpty ? NetworkImage(reel.authorAvatar) : null,
                  //   child: reel.authorAvatar.isEmpty
                  //       ? Text(
                  //     reel.authorName.isNotEmpty ? reel.authorName[0].toUpperCase() : '?',
                  //     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  //   )
                  //       : null,
                  // ),
                  // const SizedBox(width: 12),
                  // Expanded(
                  //   child: Text(
                  //     reel.authorName,
                  //     style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(height: 12),

              if (reel.caption.isNotEmpty)
                Text(
                  reel.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 8),

              if (reel.location.isNotEmpty)
                GestureDetector(
                  onTap: onNavigateToPlace,
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reel.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (reel.musicLabel != null && reel.musicLabel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reel.musicLabel!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: '$likesCount',
                color: isLiked ? Colors.red : Colors.white,
                onTap: onToggleLike,
              ),
              const SizedBox(height: 24),

              _ActionButton(
                icon: Icons.chat_bubble,
                label: '${reel.comments}',
                onTap: onShowComments,
              ),
              const SizedBox(height: 24),

              _ActionButton(
                icon: Icons.share,
                onTap: onShare,
              ),
              const SizedBox(height: 24),

              _ActionButton(
                icon: isMuted ? Icons.volume_off : Icons.volume_up,
                onTap: onToggleMute,
              ),

              if (showControls) ...[
                const SizedBox(height: 24),
                _ActionButton(
                  icon: Icons.speed,
                  label: '${playbackSpeed}x',
                  onTap: onShowSpeed,
                ),
              ],
            ],
          ),
        ),

        if (showControls)
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF0B7A4A),
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: onTogglePlayPause,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 28),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String reelId;
  final VoidCallback? onCommentAdded;

  const _CommentsSheet({
    required this.reelId,
    this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  String? _replyToId;
  String? _replyToName;
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour commenter')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final commentData = {
        'reelId': widget.reelId,
        'text': text,
        'userId': user.uid,
        'userName': user.displayName ?? 'Utilisateur',
        'userPhotoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'parentId': _replyToId,
        'replyCount': 0,
      };

      await FirebaseFirestore.instance
          .collection('reels')
          .doc(widget.reelId)
          .collection('comments')
          .add(commentData);

      if (_replyToId != null) {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .collection('comments')
            .doc(_replyToId)
            .update({'replyCount': FieldValue.increment(1)});
      } else {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.reelId)
            .update({'comments': FieldValue.increment(1)});

        widget.onCommentAdded?.call();
      }

      _commentController.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
        _isPosting = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commentaire publié !'),
          backgroundColor: Color(0xFF0B7A4A),
        ),
      );
    } catch (e) {
      setState(() => _isPosting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Commentaires',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reels')
                  .doc(widget.reelId)
                  .collection('comments')
                  .where('parentId', isNull: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Erreur de chargement', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final comments = snapshot.data!.docs;

                if (comments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Aucun commentaire', style: TextStyle(color: Colors.white54)),
                        SizedBox(height: 8),
                        Text('Soyez le premier à commenter !', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentItem(
                      reelId: widget.reelId,
                      commentId: comment.id,
                      commentData: comment.data(),
                      onReply: (id, name) {
                        setState(() {
                          _replyToId = id;
                          _replyToName = name;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          if (_replyToName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0B7A4A).withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Color(0xFF0B7A4A), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Répondre à $_replyToName',
                      style: const TextStyle(color: Color(0xFF0B7A4A), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      });
                    },
                    child: const Icon(Icons.close, color: Color(0xFF0B7A4A), size: 18),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToName != null
                          ? 'Répondre à $_replyToName...'
                          : 'Ajouter un commentaire...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    enabled: !_isPosting,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isPosting ? null : _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isPosting ? Colors.grey : const Color(0xFF0B7A4A),
                      shape: BoxShape.circle,
                    ),
                    child: _isPosting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
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

class _CommentItem extends StatefulWidget {
  final String reelId;
  final String commentId;
  final Map<String, dynamic> commentData;
  final void Function(String id, String name) onReply;

  const _CommentItem({
    required this.reelId,
    required this.commentId,
    required this.commentData,
    required this.onReply,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  bool _showReplies = false;

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'À l\'instant';
    final dateTime = (timestamp as Timestamp).toDate();
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return '${diff.inDays ~/ 7}sem';
  }

  @override
  Widget build(BuildContext context) {
    final userName = (widget.commentData['userName'] ?? 'Utilisateur').toString();
    final userPhoto = widget.commentData['userPhotoUrl']?.toString();
    final text = (widget.commentData['text'] ?? '').toString();
    final createdAt = widget.commentData['createdAt'];
    final replyCount = (widget.commentData['replyCount'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: userPhoto != null && userPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(userPhoto)
                    : null,
                child: userPhoto == null || userPhoto.isEmpty
                    ? Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onReply(widget.commentId, userName),
                          child: Text(
                            'Répondre',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (replyCount > 0) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showReplies = !_showReplies;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _showReplies ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF0B7A4A),
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showReplies
                                      ? 'Masquer'
                                      : '$replyCount réponse${replyCount > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF0B7A4A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_showReplies && replyCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 16),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('reels')
                      .doc(widget.reelId)
                      .collection('comments')
                      .where('parentId', isEqualTo: widget.commentId)
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    final replies = snapshot.data!.docs;

                    return Column(
                      children: replies.map((reply) {
                        final replyData = reply.data();
                        final replyUserName = (replyData['userName'] ?? 'Utilisateur').toString();
                        final replyUserPhoto = replyData['userPhotoUrl']?.toString();
                        final replyText = (replyData['text'] ?? '').toString();
                        final replyCreatedAt = replyData['createdAt'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                backgroundImage: replyUserPhoto != null && replyUserPhoto.isNotEmpty
                                    ? CachedNetworkImageProvider(replyUserPhoto)
                                    : null,
                                child: replyUserPhoto == null || replyUserPhoto.isEmpty
                                    ? Text(
                                  replyUserName.isNotEmpty ? replyUserName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          replyUserName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTime(replyCreatedAt),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      replyText,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
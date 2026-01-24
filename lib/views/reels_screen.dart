// lib/views/reels_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/reel.dart';
import '../models/place_enums.dart';
import 'home_screen.dart';
import 'detail_screen.dart';

class ReelsScreen extends StatefulWidget {
  final int initialIndex;
  final String? initialReelId; // Pour ouvrir un reel spécifique par ID

  const ReelsScreen({
    super.key,
    this.initialIndex = 0,
    this.initialReelId,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final PageController _pageController;

  // ✅ Liste des reels depuis Firebase
  List<Reel> _reels = [];
  bool _loadingReels = true;
  String? _reelsError;

  // Video controllers
  VideoPlayerController? _currentCtrl;
  int _currentIndex = 0;

  VideoPlayerController? _nextCtrl;
  int? _nextIndex;

  bool _loading = true;
  String? _error;

  // ✅ AUDIO
  bool _muted = false;

  // ✅ Contrôles vidéo avancés
  double _playbackSpeed = 1.0;
  bool _showControls = false;
  Timer? _hideControlsTimer;

  // Sécurisation
  int _opToken = 0;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  int? _queuedIndex;

  // Firestore refs
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String _reelKey(int index) {
    if (index < 0 || index >= _reels.length) return 'reel_$index';
    return _reels[index].id;
  }

  DocumentReference<Map<String, dynamic>> _likeDoc(String reelId, String uid) {
    return _db.collection('reels').doc(reelId).collection('likes').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _likesCol(String reelId) {
    return _db.collection('reels').doc(reelId).collection('likes');
  }

  CollectionReference<Map<String, dynamic>> _commentsCol(String reelId) {
    return _db.collection('reels').doc(reelId).collection('comments');
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
    _loadReels();
  }

  /// ✅ Charger les reels depuis Firebase
  Future<void> _loadReels() async {
    try {
      final snapshot = await _db
          .collection('reels')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      final reels = snapshot.docs.map((doc) => Reel.fromFirestore(doc)).toList();

      if (!mounted) return;

      setState(() {
        _reels = reels;
        _loadingReels = false;
      });

      if (_reels.isNotEmpty) {
        // Si on a un ID spécifique, chercher son index
        int startIndex = widget.initialIndex.clamp(0, _reels.length - 1);

        if (widget.initialReelId != null) {
          final idx = _reels.indexWhere((r) => r.id == widget.initialReelId);
          if (idx >= 0) startIndex = idx;
        }

        _currentIndex = startIndex;
        _pageController.jumpToPage(startIndex);

        await _enqueueLoad(startIndex);
        _prefetch(startIndex + 1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reelsError = 'Erreur: $e';
        _loadingReels = false;
      });
    }
  }

  VideoPlayerController _buildController(String url) {
    if (url.startsWith('assets/')) return VideoPlayerController.asset(url);
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _safeDispose(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      if (c.value.isInitialized) await c.pause();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> _applyVolume(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      await c.setVolume(_muted ? 0.0 : 1.0);
    } catch (_) {}
  }

  Future<void> _applySpeed(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      await c.setPlaybackSpeed(_playbackSpeed);
    } catch (_) {}
  }

  Future<void> _enqueueLoad(int index) async {
    if (index < 0 || index >= _reels.length) return;
    _queuedIndex = index;

    _queue = _queue.then((_) async {
      final target = _queuedIndex;
      _queuedIndex = null;
      if (target == null) return;

      await _loadIndexInternal(target);

      if (_queuedIndex != null) {
        await _enqueueLoad(_queuedIndex!);
      }
    });

    return _queue;
  }

  Future<void> _loadIndexInternal(int index) async {
    if (_disposed || _reels.isEmpty) return;
    if (index < 0 || index >= _reels.length) return;

    final int myToken = ++_opToken;
    final Reel reel = _reels[index];

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _currentIndex = index;
      });
    }

    // Promote prefetched controller
    if (_nextCtrl != null && _nextIndex == index) {
      final promoted = _nextCtrl!;
      _nextCtrl = null;
      _nextIndex = null;

      final old = _currentCtrl;
      _currentCtrl = promoted;
      await _safeDispose(old);

      if (_disposed || myToken != _opToken) return;

      try {
        await _currentCtrl!.setLooping(true);
        await _applyVolume(_currentCtrl);
        await _applySpeed(_currentCtrl);
        await _currentCtrl!.play();
      } catch (e) {
        if (_disposed || myToken != _opToken) return;
        if (mounted) {
          setState(() {
            _error = 'Impossible de lire cette vidéo.\n$e';
          });
        }
      }

      if (_disposed || myToken != _opToken) return;
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Build new controller
    final VideoPlayerController ctrl = _buildController(reel.videoUrl);

    final old = _currentCtrl;
    _currentCtrl = null;
    await _safeDispose(old);

    if (_disposed || myToken != _opToken) {
      await _safeDispose(ctrl);
      return;
    }

    _currentCtrl = ctrl;

    try {
      await ctrl.initialize().timeout(const Duration(seconds: 15));

      if (_disposed || myToken != _opToken) {
        await _safeDispose(ctrl);
        return;
      }

      await ctrl.setLooping(true);
      await _applyVolume(ctrl);
      await _applySpeed(ctrl);

      if (_disposed || myToken != _opToken) {
        await _safeDispose(ctrl);
        return;
      }

      await ctrl.play();

      if (_disposed || myToken != _opToken) return;
      if (mounted) setState(() => _loading = false);
    } on TimeoutException {
      if (_disposed || myToken != _opToken) return;

      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Chargement trop long.\nSource: ${reel.videoUrl}';
        });
      }

      await _safeDispose(ctrl);
      if (_currentCtrl == ctrl) _currentCtrl = null;
      _autoSkipIfPossible();
    } catch (e) {
      if (_disposed || myToken != _opToken) return;

      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Vidéo introuvable ou incompatible.\n$e';
        });
      }

      await _safeDispose(ctrl);
      if (_currentCtrl == ctrl) _currentCtrl = null;
      _autoSkipIfPossible();
    }
  }

  void _autoSkipIfPossible() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _disposed || _reels.isEmpty) return;
      final next = _currentIndex + 1;
      if (next < _reels.length) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _prefetch(int index) async {
    if (_disposed || _reels.isEmpty) return;
    if (index < 0 || index >= _reels.length) return;

    if (_nextCtrl != null && _nextIndex == index) return;

    final prevNext = _nextCtrl;
    _nextCtrl = null;
    _nextIndex = null;
    await _safeDispose(prevNext);

    if (_disposed) return;

    final reel = _reels[index];
    final ctrl = _buildController(reel.videoUrl);

    try {
      await ctrl.initialize().timeout(const Duration(seconds: 15));
      if (_disposed) {
        await _safeDispose(ctrl);
        return;
      }

      await ctrl.setLooping(true);
      await _applyVolume(ctrl);
      await _applySpeed(ctrl);

      if (_disposed) {
        await _safeDispose(ctrl);
        return;
      }

      _nextCtrl = ctrl;
      _nextIndex = index;
    } catch (_) {
      await _safeDispose(ctrl);
    }
  }

  Future<void> _onPageChanged(int index) async {
    try {
      await _currentCtrl?.pause();
    } catch (_) {}

    await _enqueueLoad(index);
    _prefetch(index + 1);
  }

  // ✅ CONTRÔLES VIDÉO AVANCÉS
  void _showVideoControls() {
    setState(() => _showControls = true);
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _seekForward() async {
    final c = _currentCtrl;
    if (c == null || !c.value.isInitialized) return;

    final current = c.value.position;
    final duration = c.value.duration;
    final newPos = current + const Duration(seconds: 10);
    await c.seekTo(newPos > duration ? duration : newPos);
    _showVideoControls();
  }

  Future<void> _seekBackward() async {
    final c = _currentCtrl;
    if (c == null || !c.value.isInitialized) return;

    final current = c.value.position;
    final newPos = current - const Duration(seconds: 10);
    await c.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
    _showVideoControls();
  }

  Future<void> _togglePlayPause() async {
    final c = _currentCtrl;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    setState(() {});
    _showVideoControls();
  }

  Future<void> _cycleSpeed() async {
    final speeds = [1.0, 1.25, 1.5, 2.0, 0.5, 0.75];
    final currentIdx = speeds.indexOf(_playbackSpeed);
    final nextIdx = (currentIdx + 1) % speeds.length;

    setState(() => _playbackSpeed = speeds[nextIdx]);
    await _applySpeed(_currentCtrl);
    _toast('Vitesse: ${_playbackSpeed}x');
    _showVideoControls();
  }

  Future<void> _toggleLikeFirestore(String reelId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _toast('Connectez-vous pour liker.');
      return;
    }

    final likeRef = _likeDoc(reelId, user.uid);

    try {
      final snap = await likeRef.get();
      if (snap.exists) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _toast('Erreur like: $e');
    }
  }

  Future<void> _openCommentsFirestore(String reelId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheetFirestore(reelId: reelId),
    );
  }

  /// ✅ Ouvrir le bottom sheet avec les détails du lieu
  Future<void> _openPlaceDetails(Reel reel) async {
    if (!reel.hasLinkedPlace) {
      _toast('Aucun lieu lié à ce reel');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceDetailsSheet(
        placeId: reel.placeId!,
        placeCategory: reel.placeCategory!,
        placeName: reel.placeName,
      ),
    );
  }

  Future<void> _shareCurrent() async {
    if (_reels.isEmpty) return;
    final reel = _reels[_currentIndex];
    final text = 'Découvre ce reel sur Kin City Guide!\n${reel.caption}\n${reel.videoUrl}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _toast('Lien copié!');
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _applyVolume(_currentCtrl);
    await _applyVolume(_nextCtrl);
    if (!mounted) return;
    _toast(_muted ? 'Son coupé' : 'Son activé');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1200)),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _hideControlsTimer?.cancel();
    _pageController.dispose();
    _opToken++;

    Future.microtask(() async {
      await _safeDispose(_currentCtrl);
      await _safeDispose(_nextCtrl);
      _currentCtrl = null;
      _nextCtrl = null;
    });

    super.dispose();
  }

  // Streams
  Stream<DocumentSnapshot<Map<String, dynamic>>> _myLikeStream(String reelId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _likeDoc(reelId, user.uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _likesStream(String reelId) {
    return _likesCol(reelId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _commentsStream(String reelId) {
    return _commentsCol(reelId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_loadingReels) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Error state
    if (_reelsError != null || _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_library_outlined, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                _reelsError ?? 'Aucun reel disponible',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
                },
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (_, index) {
          final reel = _reels[index];
          final isCurrent = index == _currentIndex;
          final ctrl = isCurrent ? _currentCtrl : null;
          final reelId = reel.id;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ✅ Video Player avec double tap pour contrôles
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isCurrent) return;
                  _togglePlayPause();
                },
                onDoubleTapDown: (details) {
                  if (!isCurrent) return;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final tapX = details.globalPosition.dx;

                  if (tapX < screenWidth / 3) {
                    _seekBackward();
                  } else if (tapX > screenWidth * 2 / 3) {
                    _seekForward();
                  } else {
                    _toggleLikeFirestore(reelId);
                  }
                },
                onLongPress: _showVideoControls,
                child: (isCurrent && ctrl != null && ctrl.value.isInitialized && _error == null)
                    ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: ctrl.value.size.width,
                      height: ctrl.value.size.height,
                      child: VideoPlayer(ctrl),
                    ),
                  ),
                )
                    : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      isCurrent ? (_error ?? 'Chargement...') : '',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Loading indicator
              if (isCurrent && _loading)
                const Center(child: CircularProgressIndicator(color: Colors.white)),

              // Play icon when paused
              if (isCurrent && ctrl != null && ctrl.value.isInitialized && !ctrl.value.isPlaying && _error == null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                ),

              // ✅ Contrôles vidéo avancés (si visible)
              if (isCurrent && _showControls)
                _VideoControlsOverlay(
                  controller: ctrl,
                  playbackSpeed: _playbackSpeed,
                  onSeekBackward: _seekBackward,
                  onSeekForward: _seekForward,
                  onPlayPause: _togglePlayPause,
                  onSpeedChange: _cycleSpeed,
                ),

              // ✅ Progress bar
              if (isCurrent && ctrl != null && ctrl.value.isInitialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _VideoProgressBar(controller: ctrl),
                ),

              // TOP LEFT: Back button
              Positioned(
                left: 14,
                top: MediaQuery.of(context).padding.top + 10,
                child: _CircleIconButton(
                  icon: Icons.arrow_back,
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                ),
              ),

              // TOP RIGHT: Mute + Speed
              Positioned(
                right: 14,
                top: MediaQuery.of(context).padding.top + 10,
                child: Row(
                  children: [
                    // Speed indicator
                    if (_playbackSpeed != 1.0)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    _CircleIconButton(
                      icon: _muted ? Icons.volume_off : Icons.volume_up,
                      onTap: _toggleMute,
                    ),
                  ],
                ),
              ),

              // RIGHT: Actions (Like, Comment, Share)
              Positioned(
                right: 14,
                bottom: 140,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _likesStream(reelId),
                  builder: (context, likesSnap) {
                    final likes = likesSnap.hasData ? likesSnap.data!.size : 0;

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _commentsStream(reelId),
                      builder: (context, commentsSnap) {
                        final comments = commentsSnap.hasData ? commentsSnap.data!.size : 0;

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _myLikeStream(reelId),
                          builder: (context, myLikeSnap) {
                            final user = _auth.currentUser;
                            final liked = user != null && (myLikeSnap.data?.exists == true);

                            return _RightActions(
                              liked: liked,
                              likes: likes,
                              comments: comments,
                              onLike: () => _toggleLikeFirestore(reelId),
                              onComment: () => _openCommentsFirestore(reelId),
                              onShare: _shareCurrent,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // BOTTOM LEFT: Info + CTA Lieu
              Positioned(
                left: 14,
                right: 84,
                bottom: 28,
                child: _BottomInfo(
                  reel: reel,
                  onPlaceTap: reel.hasLinkedPlace ? () => _openPlaceDetails(reel) : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =========================================================================
// ✅ WIDGETS AUXILIAIRES
// =========================================================================

class _VideoProgressBar extends StatelessWidget {
  final VideoPlayerController? controller;

  const _VideoProgressBar({this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller!,
      builder: (context, value, _) {
        final duration = value.duration.inMilliseconds;
        final position = value.position.inMilliseconds;
        final progress = duration > 0 ? position / duration : 0.0;

        return Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoControlsOverlay extends StatelessWidget {
  final VideoPlayerController? controller;
  final double playbackSpeed;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onPlayPause;
  final VoidCallback onSpeedChange;

  const _VideoControlsOverlay({
    this.controller,
    required this.playbackSpeed,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onPlayPause,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller?.value.isPlaying ?? false;

    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reculer 10s
              _ControlButton(
                icon: Icons.replay_10,
                label: '-10s',
                onTap: onSeekBackward,
              ),
              // Play/Pause
              _ControlButton(
                icon: isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 70,
                onTap: onPlayPause,
              ),
              // Avancer 10s
              _ControlButton(
                icon: Icons.forward_10,
                label: '+10s',
                onTap: onSeekForward,
              ),
            ],
          ),
          const SizedBox(height: 30),
          // Vitesse
          GestureDetector(
            onTap: onSpeedChange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Vitesse: ${playbackSpeed}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    this.label,
    required this.onTap,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: size),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  final bool liked;
  final int likes;
  final int comments;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _RightActions({
    required this.liked,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    const iconSize = 28.0;
    const textStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);

    Widget item({
      required IconData icon,
      String? label,
      required VoidCallback onTap,
      Color? iconColor,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            Material(
              color: Colors.white.withOpacity(0.18),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(icon, color: iconColor ?? Colors.white, size: iconSize),
                ),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(label, style: textStyle),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        item(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: '$likes',
          onTap: onLike,
          iconColor: liked ? Colors.redAccent : Colors.white,
        ),
        item(
          icon: Icons.chat_bubble_outline,
          label: '$comments',
          onTap: onComment,
        ),
        item(icon: Icons.share_outlined, onTap: onShare),
      ],
    );
  }
}

class _BottomInfo extends StatelessWidget {
  final Reel reel;
  final VoidCallback? onPlaceTap;

  const _BottomInfo({required this.reel, this.onPlaceTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auteur
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.15),
              backgroundImage: reel.authorAvatar.isNotEmpty
                  ? (reel.authorAvatar.startsWith('assets/')
                  ? AssetImage(reel.authorAvatar) as ImageProvider
                  : NetworkImage(reel.authorAvatar))
                  : null,
              child: reel.authorAvatar.isEmpty
                  ? Text(
                reel.authorName.isNotEmpty ? reel.authorName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reel.authorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Caption
        if (reel.caption.isNotEmpty)
          Text(
            reel.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.25,
            ),
          ),
        const SizedBox(height: 10),

        // Location + CTA Lieu
        Row(
          children: [
            // Location pill
            if (reel.location.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      reel.location,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            // ✅ CTA pour voir le lieu lié
            if (onPlaceTap != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onPlaceTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B7A4A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        reel.placeName ?? 'Voir le lieu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        // Musique
        if ((reel.musicLabel ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reel.musicLabel!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
// =========================================================================
// ✅ PLACE DETAILS BOTTOM SHEET (inspiré de detail_screen)
// =========================================================================

class _PlaceDetailsSheet extends StatefulWidget {
  final String placeId;
  final String placeCategory;
  final String? placeName;

  const _PlaceDetailsSheet({
    required this.placeId,
    required this.placeCategory,
    this.placeName,
  });

  @override
  State<_PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends State<_PlaceDetailsSheet> {
  Map<String, dynamic>? _placeData;
  bool _loading = true;
  String? _error;

  static const Color _green = Color(0xFF0B7A4A);

  @override
  void initState() {
    super.initState();
    _loadPlace();
  }

  Future<void> _loadPlace() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(widget.placeCategory)
          .doc(widget.placeId)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _error = 'Lieu introuvable';
          _loading = false;
        });
        return;
      }

      setState(() {
        _placeData = doc.data();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur: $e';
        _loading = false;
      });
    }
  }

  PlaceCategory? _getPlaceCategory() {
    switch (widget.placeCategory) {
      case 'sites':
        return PlaceCategory.site;
      case 'hotels':
        return PlaceCategory.hotel;
      case 'restaurants':
        return PlaceCategory.resto;
      case 'events':
        return PlaceCategory.event;
      case 'business':
        return PlaceCategory.entreprise;
      case 'shopping':
        return PlaceCategory.shopping;
      default:
        return null;
    }
  }

  void _openFullDetails() {
    final category = _getPlaceCategory();
    if (category == null || _placeData == null) return;

    Navigator.of(context).pop(); // Fermer le bottom sheet

    // Créer un objet place dynamique
    final place = _PlaceWrapper(
      id: widget.placeId,
      data: _placeData!,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          place: place,
          category: category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.65,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.placeName ?? 'Détails du lieu',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            )
                : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_placeData == null) return const SizedBox.shrink();

    final data = _placeData!;
    final nom = (data['nom'] ?? 'Sans nom').toString();
    final description = (data['description'] ?? '').toString();
    final photos = (data['photos'] as List?)?.cast<String>() ?? [];
    final address = (data['address'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final prixRange = (data['prixRange'] ?? '').toString();
    final rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
    final schedule = (data['schedule'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos carousel
          if (photos.isNotEmpty)
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return Container(
                    width: 260,
                    margin: EdgeInsets.only(right: index < photos.length - 1 ? 12 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: photo.startsWith('assets/')
                            ? AssetImage(photo) as ImageProvider
                            : NetworkImage(photo),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),

          // Nom
          Text(
            nom,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          // Meta pills
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (rating > 0)
                _MetaPill(
                  icon: Icons.star,
                  text: rating.toStringAsFixed(1),
                  color: const Color(0xFFD2A100),
                ),
              if (prixRange.isNotEmpty)
                _MetaPill(
                  icon: Icons.payments_outlined,
                  text: prixRange,
                ),
              if (schedule.isNotEmpty)
                _MetaPill(
                  icon: Icons.schedule,
                  text: schedule,
                ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Description',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
            ),
          ],

          // Contact info
          if (address.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Contact',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (address.isNotEmpty)
              _ContactRow(icon: Icons.place, text: address),
            if (phone.isNotEmpty)
              _ContactRow(icon: Icons.phone, text: phone),
          ],

          const SizedBox(height: 30),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openFullDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text(
                'Voir tous les détails',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MetaPill({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Wrapper pour passer les données au DetailScreen
class _PlaceWrapper {
  final String id;
  final Map<String, dynamic> data;

  _PlaceWrapper({required this.id, required this.data});

  String get nom => (data['nom'] ?? '').toString();
  String get description => (data['description'] ?? '').toString();
  List<dynamic> get photos => (data['photos'] as List?) ?? [];
  double get rating => (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
  String get prixRange => (data['prixRange'] ?? '').toString();
  double? get latitude => (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null;
  double? get longitude => (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null;
  String? get address => data['address']?.toString();
  String? get phone => data['phone']?.toString();
  String? get email => data['email']?.toString();
  String? get website => data['website']?.toString();
  String? get facebookUrl => data['facebookUrl']?.toString();
  String? get instagramUrl => data['instagramUrl']?.toString();
  String? get tiktokUrl => data['tiktokUrl']?.toString();
  List<String> get amenities => (data['amenities'] as List?)?.cast<String>() ?? [];
  String? get schedule => data['schedule']?.toString();
}

// =========================================================================
// ✅ COMMENTS SHEET AVEC RÉPONSES
// =========================================================================

class _CommentsSheetFirestore extends StatefulWidget {
  final String reelId;
  const _CommentsSheetFirestore({required this.reelId});

  @override
  State<_CommentsSheetFirestore> createState() => _CommentsSheetFirestoreState();
}

class _CommentsSheetFirestoreState extends State<_CommentsSheetFirestore> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool _sending = false;
  String? _error;

  // ✅ Pour les réponses
  String? _replyingToId;
  String? _replyingToName;

  static const Color _green = Color(0xFF0B7A4A);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reels').doc(widget.reelId).collection('comments');

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToId = commentId;
      _replyingToName = userName;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
  }

  Future<void> _addComment() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Connectez-vous pour commenter.');
      return;
    }

    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final commentData = {
        'userId': user.uid,
        'userName': (user.displayName ?? 'Utilisateur').trim(),
        'userPhotoUrl': user.photoURL,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'parentId': _replyingToId,
        'replyCount': 0,
      };

      await _col.add(commentData);

      // Si c'est une réponse, incrémenter le compteur du parent
      if (_replyingToId != null) {
        await _col.doc(_replyingToId).update({
          'replyCount': FieldValue.increment(1),
        });
      }

      _ctrl.clear();
      _cancelReply();
    } catch (e) {
      setState(() => _error = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      // Supprimer les réponses associées
      final replies = await _col.where('parentId', isEqualTo: commentId).get();
      for (final reply in replies.docs) {
        await reply.reference.delete();
      }
      // Supprimer le commentaire
      await _col.doc(commentId).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: media.size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Commentaires',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),

            const Divider(height: 1, color: Color(0xFF2A2A2A)),

            // Comments list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _col
                    .where('parentId', isNull: true)
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Erreur: ${snap.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white30),
                          SizedBox(height: 12),
                          Text(
                            'Aucun commentaire.\nSoyez le premier à commenter!',
                            style: TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _CommentTile(
                        commentId: doc.id,
                        data: doc.data(),
                        reelId: widget.reelId,
                        onReply: (id, name) => _startReply(id, name),
                        onDelete: () => _deleteComment(doc.id),
                        currentUserId: _auth.currentUser?.uid,
                      );
                    },
                  );
                },
              ),
            ),

            // Reply indicator
            if (_replyingToId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _green.withOpacity(0.15),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Répondre à $_replyingToName',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: const Icon(Icons.close, size: 18, color: Colors.white54),
                    ),
                  ],
                ),
              ),

            // Input field
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + media.padding.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0A0A),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: _auth.currentUser?.photoURL != null
                        ? NetworkImage(_auth.currentUser!.photoURL!)
                        : null,
                    child: _auth.currentUser?.photoURL == null
                        ? Text(
                      (_auth.currentUser?.displayName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _replyingToId != null
                            ? 'Écrire une réponse...'
                            : 'Ajouter un commentaire...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sending ? null : _addComment(),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send button
                  Material(
                    color: _green,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _sending ? null : _addComment,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _sending
                            ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.send, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// ✅ COMMENT TILE AVEC RÉPONSES
// =========================================================================

class _CommentTile extends StatefulWidget {
  final String commentId;
  final Map<String, dynamic> data;
  final String reelId;
  final Function(String id, String name) onReply;
  final VoidCallback onDelete;
  final String? currentUserId;

  const _CommentTile({
    required this.commentId,
    required this.data,
    required this.reelId,
    required this.onReply,
    required this.onDelete,
    this.currentUserId,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplies = false;

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final userName = (data['userName'] ?? 'Utilisateur').toString();
    final userPhotoUrl = data['userPhotoUrl']?.toString();
    final text = (data['text'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();
    final replyCount = (data['replyCount'] is num) ? (data['replyCount'] as num).toInt() : 0;
    final createdAt = data['createdAt'];

    final isOwner = widget.currentUserId == userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main comment
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.12),
              backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl) : null,
              child: userPhotoUrl == null
                  ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              )
                  : null,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Time
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Text
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Actions
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
                          onTap: () => setState(() => _showReplies = !_showReplies),
                          child: Text(
                            _showReplies
                                ? 'Masquer les réponses'
                                : 'Voir $replyCount réponse${replyCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Color(0xFF0B7A4A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isOwner)
                        GestureDetector(
                          onTap: widget.onDelete,
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Replies
        if (_showReplies && replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reels')
                  .doc(widget.reelId)
                  .collection('comments')
                  .where('parentId', isEqualTo: widget.commentId)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  );
                }

                final replies = snap.data!.docs;

                return Column(
                  children: replies.map((reply) {
                    final replyData = reply.data();
                    final replyUserName = (replyData['userName'] ?? 'Utilisateur').toString();
                    final replyUserPhoto = replyData['userPhotoUrl']?.toString();
                    final replyText = (replyData['text'] ?? '').toString();
                    final replyUserId = (replyData['userId'] ?? '').toString();
                    final replyCreatedAt = replyData['createdAt'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            backgroundImage: replyUserPhoto != null
                                ? NetworkImage(replyUserPhoto)
                                : null,
                            child: replyUserPhoto == null
                                ? Text(
                              replyUserName.isNotEmpty ? replyUserName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
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
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(replyCreatedAt),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  replyText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.currentUserId == replyUserId)
                            GestureDetector(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                    .collection('reels')
                                    .doc(widget.reelId)
                                    .collection('comments')
                                    .doc(reply.id)
                                    .delete();

                                // Décrémenter le compteur
                                await FirebaseFirestore.instance
                                    .collection('reels')
                                    .doc(widget.reelId)
                                    .collection('comments')
                                    .doc(widget.commentId)
                                    .update({
                                  'replyCount': FieldValue.increment(-1),
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white.withOpacity(0.4),
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

        const SizedBox(height: 16),
        Divider(color: Colors.white.withOpacity(0.1), height: 1),
        const SizedBox(height: 16),
      ],
    );
  }
}
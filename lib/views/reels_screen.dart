import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kin_experience/controllers/location_controller.dart';
import 'package:kin_experience/views/home_screen.dart';
import 'package:video_player/video_player.dart';

import '../data/fake_reels.dart';
import '../models/reel.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();



  // ✅ On garde au maximum 2 controllers: current + prefetched next
  VideoPlayerController? _currentCtrl;
  int _currentIndex = 0;

  VideoPlayerController? _nextCtrl;
  int? _nextIndex;

  bool _loading = true;
  String? _error;

  // ✅ AUDIO
  bool _muted = false; // 🔊 son ON par défaut

  // ✅ Sécurisation: éviter les races (init/dispose concurrent)
  int _opToken = 0;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  int? _queuedIndex;

  // =========================
  // ✅ Firestore refs
  // =========================
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // -------------------------
  // Reel Key (ID stable)
  // -------------------------
  String _reelKey(int index) {
    // Si votre modèle Reel possède un champ id, vous pouvez faire:
    // final id = (fakeReels[index].id ?? '').toString().trim();
    // return id.isNotEmpty ? id : 'reel_$index';
    return 'reel_$index'; // fallback simple, stable
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

  // =========================
  // VIDEO LOADING LOGIC
  // =========================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _enqueueLoad(0);
      _prefetch(1);
    });
  }

  VideoPlayerController _buildController(String url) {
    if (url.startsWith('assets/')) return VideoPlayerController.asset(url);
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _safeDispose(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      if (c.value.isInitialized) {
        await c.pause();
      }
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

  Future<void> _enqueueLoad(int index) async {
    if (index < 0 || index >= fakeReels.length) return;
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
    if (_disposed) return;

    final int myToken = ++_opToken;
    final Reel reel = fakeReels[index];

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _currentIndex = index;
      });
    }

    // ✅ Promote prefetched controller if available
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
        await _currentCtrl!.play();
      } catch (e) {
        if (_disposed || myToken != _opToken) return;
        if (mounted) {
          setState(() {
            _error = 'Impossible de lire cette vidéo.\n\nSource: ${reel.videoUrl}\n$e';
          });
        }
      }

      if (_disposed || myToken != _opToken) return;
      if (mounted) setState(() => _loading = false);
      return;
    }

    // ✅ Build new controller
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
      await ctrl.initialize().timeout(const Duration(seconds: 12));

      if (_disposed || myToken != _opToken) {
        await _safeDispose(ctrl);
        return;
      }

      await ctrl.setLooping(true);
      await _applyVolume(ctrl);

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
          _error = 'Chargement trop long (timeout).\n'
              'Cette vidéo peut être trop lourde ou incompatible.\n\n'
              'Source: ${reel.videoUrl}';
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
          _error = 'Vidéo introuvable, invalide ou incompatible.\n'
              'Source: ${reel.videoUrl}\n\n'
              '$e';
        });
      }

      await _safeDispose(ctrl);
      if (_currentCtrl == ctrl) _currentCtrl = null;

      _autoSkipIfPossible();
    }
  }

  void _autoSkipIfPossible() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _disposed) return;
      final next = _currentIndex + 1;
      if (next < fakeReels.length) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _prefetch(int index) async {
    if (_disposed) return;
    if (index < 0 || index >= fakeReels.length) return;

    if (_nextCtrl != null && _nextIndex == index) return;

    final prevNext = _nextCtrl;
    _nextCtrl = null;
    _nextIndex = null;
    await _safeDispose(prevNext);

    if (_disposed) return;

    final reel = fakeReels[index];
    final ctrl = _buildController(reel.videoUrl);

    try {
      await ctrl.initialize().timeout(const Duration(seconds: 12));
      if (_disposed) {
        await _safeDispose(ctrl);
        return;
      }

      await ctrl.setLooping(true);
      await _applyVolume(ctrl);

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

  // =========================
  // ✅ FIRESTORE: LIKE TOGGLE (FIXED)
  // =========================
  // IMPORTANT: on n'écrit PAS dans reels/{reelId} ici (sinon permission-denied)
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
        // unlike
        await likeRef.delete();
      } else {
        // like
        await likeRef.set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _toast('Erreur like: $e');
    }
  }

  // =========================
  // ✅ FIRESTORE: COMMENTS (FIXED)
  // =========================
  Future<void> _openCommentsFirestore(String reelId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _toast('Connectez-vous pour commenter.');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheetFirestore(reelId: reelId),
    );
  }

  Future<void> _shareCurrent() async {
    final reel = fakeReels[_currentIndex];
    await Clipboard.setData(ClipboardData(text: reel.videoUrl));
    if (!mounted) return;
    _toast('Lien copié. Collez-le pour partager.');
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
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  @override
  void dispose() {
    _disposed = true;
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

  // =========================
  // ✅ Streams for UI
  // =========================
  Stream<DocumentSnapshot<Map<String, dynamic>>> _myLikeStream(String reelId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _likeDoc(reelId, user.uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _likesStream(String reelId) {
    // Compteur simple (MVP): snapshot size
    return _likesCol(reelId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _commentsStream(String reelId) {
    // Compteur simple (MVP): snapshot size
    return _commentsCol(reelId).snapshots();
  }


  @override
  Widget build(BuildContext context) {
    //final posAsync = ref.watch(userPositionProvider);

    return Scaffold(

      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: fakeReels.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (_, index) {
          final reel = fakeReels[index];
          final isCurrent = index == _currentIndex;
          final ctrl = isCurrent ? _currentCtrl : null;


          final reelId = _reelKey(index);

          // fallback counts from fake (avant que Firestore ait de data)
          final fallbackLikes = reel.likes;
          final fallbackComments = reel.comments;

          return Stack(
            fit: StackFit.expand,
            children: [
              // =========================
              // VIDEO (tap to play/pause)
              // =========================
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isCurrent) return;
                  final c = _currentCtrl;
                  if (c == null || !c.value.isInitialized) return;

                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                  setState(() {});
                },
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
                      isCurrent ? (_error ?? 'Chargement de la vidéo...') : '',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              if (isCurrent && _loading) const Center(child: CircularProgressIndicator()),

              if (isCurrent &&
                  ctrl != null &&
                  ctrl.value.isInitialized &&
                  !ctrl.value.isPlaying &&
                  _error == null)
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

              // =========================
              // TOP BACK BUTTON
              // =========================
              Positioned(
                left: 14,
                top: MediaQuery.of(context).padding.top + 10,
                child: _CircleIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                ),
              ),

              // =========================
              // TOP RIGHT: MUTE/UNMUTE
              // =========================
              Positioned(
                right: 14,
                top: MediaQuery.of(context).padding.top + 10,
                child: _CircleIconButton(
                  icon: _muted ? Icons.volume_off : Icons.volume_up,
                  onTap: _toggleMute,
                ),
              ),

              // =========================
              // RIGHT ACTIONS (Firestore FIXED)
              // =========================
              Positioned(
                right: 14,
                bottom: 140,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _likesStream(reelId),
                  builder: (context, likesSnap) {
                    final likes = likesSnap.hasData ? likesSnap.data!.size : fallbackLikes;

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _commentsStream(reelId),
                      builder: (context, commentsSnap) {
                        final comments =
                        commentsSnap.hasData ? commentsSnap.data!.size : fallbackComments;

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

              // =========================
              // BOTTOM LEFT INFO
              // =========================
              Positioned(
                left: 14,
                right: 84,
                bottom: 28,
                child: _BottomInfo(reel: reel),
              ),
            ],
          );
        },
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
  const _BottomInfo({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.15),
              backgroundImage: reel.authorAvatar.startsWith('assets/')
                  ? AssetImage(reel.authorAvatar) as ImageProvider
                  : NetworkImage(reel.authorAvatar),
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
        Row(
          children: [
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
            const SizedBox(width: 10),
            if ((reel.musicLabel ?? '').trim().isNotEmpty)
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
    );
  }
}

// ===================================================================
// ✅ COMMENTS SHEET (Firestore FIXED)
// ===================================================================

class _CommentsSheetFirestore extends StatefulWidget {
  final String reelId;
  const _CommentsSheetFirestore({required this.reelId});

  @override
  State<_CommentsSheetFirestore> createState() => _CommentsSheetFirestoreState();
}

class _CommentsSheetFirestoreState extends State<_CommentsSheetFirestore> {
  final TextEditingController _ctrl = TextEditingController();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool _sending = false;
  String? _error;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reels').doc(widget.reelId).collection('comments');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
      await _col.add({
        'userId': user.uid,
        'userName': (user.displayName ?? 'Utilisateur').trim(),
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _ctrl.clear();
    } catch (e) {
      setState(() => _error = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
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
        height: media.size.height * 0.72,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Commentaires',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),

            const Divider(height: 1, color: Color(0xFF2A2A2A)),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _col.orderBy('createdAt', descending: true).limit(50).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Erreur de chargement.\n${snap.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Aucun commentaire.', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final name = (d['userName'] ?? 'Utilisateur').toString();
                      final text = (d['text'] ?? '').toString();

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withOpacity(0.12),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    text,
                                    style: const TextStyle(color: Colors.white70, height: 1.25),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sending ? null : _addComment(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _sending ? null : _addComment,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: _sending
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.send, color: Colors.white),
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

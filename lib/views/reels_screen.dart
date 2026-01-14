import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // ✅ Interactions dynamiques (local state)
  // =========================
  late List<int> _likes;
  late List<int> _commentsCount;
  late List<bool> _liked;
  late List<bool> _bookmarked;

  // commentaires par reel (fake dynamique)
  final Map<int, List<_ReelComment>> _commentsByIndex = {};

  @override
  void initState() {
    super.initState();

    _likes = fakeReels.map((r) => r.likes).toList();
    _commentsCount = fakeReels.map((r) => r.comments).toList();
    _liked = List<bool>.filled(fakeReels.length, false);
    _bookmarked = List<bool>.filled(fakeReels.length, false);

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
      // 0.0 mute / 1.0 full volume
      await c.setVolume(_muted ? 0.0 : 1.0);
    } catch (_) {}
  }

  // =========================
  // ✅ QUEUE: garantit qu'on ne fait pas init/dispose en parallèle
  // =========================
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

    // ✅ 1) Promote prefetched controller if available
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
            _error =
            'Impossible de lire cette vidéo.\n\nSource: ${reel.videoUrl}\n$e';
          });
        }
      }

      if (_disposed || myToken != _opToken) return;
      if (mounted) setState(() => _loading = false);
      return;
    }

    // ✅ 2) Build new controller
    final VideoPlayerController ctrl = _buildController(reel.videoUrl);

    // IMPORTANT: dispose current first, then init new (réduit crash JNI)
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
    } on TimeoutException catch (_) {
      if (_disposed || myToken != _opToken) return;

      if (mounted) {
        setState(() {
          _loading = false;
          _error =
          'Chargement trop long (timeout).\n'
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
          _error =
          'Vidéo introuvable, invalide ou incompatible.\n'
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
  // ✅ ACTIONS DYNAMIQUES
  // =========================

  void _toggleLike() {
    final i = _currentIndex;
    setState(() {
      _liked[i] = !_liked[i];
      _likes[i] += _liked[i] ? 1 : -1;
      if (_likes[i] < 0) _likes[i] = 0;
    });
  }

  void _toggleBookmark() {
    final i = _currentIndex;
    setState(() => _bookmarked[i] = !_bookmarked[i]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bookmarked[i] ? 'Ajouté aux favoris' : 'Retiré des favoris'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _shareCurrent() async {
    final reel = fakeReels[_currentIndex];
    await Clipboard.setData(ClipboardData(text: reel.videoUrl));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien copié. Collez-le pour partager.'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _openComments() async {
    final i = _currentIndex;
    final reel = fakeReels[i];

    _commentsByIndex.putIfAbsent(i, () {
      return <_ReelComment>[
        _ReelComment(
          author: reel.authorName,
          text: 'Bienvenue sur Kin-Experience.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ];
    });

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        title: 'Commentaires',
        comments: _commentsByIndex[i]!,
      ),
    );

    if (added == true) {
      setState(() {
        _commentsCount[i] = _commentsByIndex[i]!.length;
      });
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);

    // applique au current + next (si déjà initialisés)
    await _applyVolume(_currentCtrl);
    await _applyVolume(_nextCtrl);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_muted ? 'Son coupé' : 'Son activé'),
        duration: const Duration(milliseconds: 650),
      ),
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

  @override
  Widget build(BuildContext context) {
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
                child: (isCurrent &&
                    ctrl != null &&
                    ctrl.value.isInitialized &&
                    _error == null)
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

              if (isCurrent && _loading)
                const Center(child: CircularProgressIndicator()),

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
              // RIGHT ACTIONS (DYNAMIQUES)
              // =========================
              Positioned(
                right: 14,
                bottom: 140,
                child: _RightActions(
                  liked: _liked[_currentIndex],
                  bookmarked: _bookmarked[_currentIndex],
                  likes: _likes[_currentIndex],
                  comments: _commentsCount[_currentIndex],
                  onLike: _toggleLike,
                  onComment: _openComments,
                  onShare: _shareCurrent,
                  onBookmark: _toggleBookmark,
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
  final bool bookmarked;
  final int likes;
  final int comments;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const _RightActions({
    required this.liked,
    required this.bookmarked,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    const iconSize = 28.0;
    const textStyle =
    TextStyle(color: Colors.white, fontWeight: FontWeight.w700);

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
                  child: Icon(icon,
                      color: iconColor ?? Colors.white, size: iconSize),
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
        // item(
        //   icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
        //   onTap: onBookmark,
        // ),
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
// ✅ COMMENTS SHEET (opérationnel + dynamique)
// ===================================================================

class _ReelComment {
  final String author;
  final String text;
  final DateTime createdAt;

  _ReelComment({
    required this.author,
    required this.text,
    required this.createdAt,
  });
}

class _CommentsSheet extends StatefulWidget {
  final String title;
  final List<_ReelComment> comments;

  const _CommentsSheet({
    required this.title,
    required this.comments,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      widget.comments.insert(
        0,
        _ReelComment(
          author: 'Vous',
          text: text,
          createdAt: DateTime.now(),
        ),
      );
    });

    _ctrl.clear();
    Navigator.of(context).pop(true);
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
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
                  Expanded(
                    child: Text(
                      '${widget.title} (${widget.comments.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            Expanded(
              child: widget.comments.isEmpty
                  ? const Center(
                child: Text(
                  'Aucun commentaire.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: widget.comments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = widget.comments[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        child: Text(
                          c.author.isNotEmpty
                              ? c.author[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.author,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(c.createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                c.text,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                border: Border(
                  top: BorderSide(color: Color(0xFF2A2A2A)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.55)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _addComment,
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.send, color: Colors.white),
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

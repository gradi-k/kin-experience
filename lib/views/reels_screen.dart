import 'package:flutter/material.dart';
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
  final Map<int, VideoPlayerController> _controllers = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareController(0);
      await _controllers[0]?.play();
      _prepareController(1);
    });
  }

  VideoPlayerController _buildController(String url) {
    // ✅ Assets MP4
    if (url.startsWith('assets/')) {
      return VideoPlayerController.asset(url);
    }
    // ✅ Network
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _prepareController(int index) async {
    if (index < 0 || index >= fakeReels.length) return;
    if (_controllers.containsKey(index)) return;

    final reel = fakeReels[index];

    final ctrl = _buildController(reel.videoUrl);
    _controllers[index] = ctrl;

    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);

      if (!mounted) return;

      // ✅ If active page => play
      if (index == _currentIndex) {
        await ctrl.play();
      }

      setState(() {});
    } catch (e) {
      // If init fails, keep controller but show errorDescription in UI
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _onPageChanged(int index) async {
    setState(() => _currentIndex = index);

    // stop old
    for (final entry in _controllers.entries) {
      if (entry.key != index) {
        entry.value.pause();
      }
    }

    // start current
    await _prepareController(index);
    await _controllers[index]?.play();

    // prefetch next/prev
    _prepareController(index + 1);
    _prepareController(index - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
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
          final ctrl = _controllers[index];

          return Stack(
            fit: StackFit.expand,
            children: [
              // =========================
              // VIDEO (tap to play/pause)
              // =========================
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final c = _controllers[index];
                  if (c == null) return;

                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                  }
                  setState(() {});
                },
                child: (ctrl != null && ctrl.value.isInitialized)
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
                  child: Text(
                    ctrl?.value.errorDescription ??
                        'Chargement de la vidéo...',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Optional: small play icon overlay when paused (like reels)
              if (ctrl != null &&
                  ctrl.value.isInitialized &&
                  !ctrl.value.isPlaying)
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
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),

              // =========================
              // RIGHT ACTIONS
              // =========================
              Positioned(
                right: 14,
                bottom: 140,
                child: _RightActions(
                  likes: reel.likes,
                  comments: reel.comments,
                  onLike: () {},
                  onComment: () {},
                  onShare: () {},
                  onBookmark: () {},
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
  final int likes;
  final int comments;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const _RightActions({
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
                  child: Icon(icon, color: Colors.white, size: iconSize),
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
        item(icon: Icons.favorite_border, label: '$likes', onTap: onLike),
        item(
            icon: Icons.chat_bubble_outline,
            label: '$comments',
            onTap: onComment),
        item(icon: Icons.share_outlined, onTap: onShare),
        item(icon: Icons.bookmark_border, onTap: onBookmark),
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
                  const Icon(Icons.play_arrow,
                      color: Colors.white, size: 18),
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

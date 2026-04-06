// lib/views/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const String kSeenOnboardingKey = 'seen_onboarding';

  Future<void> _finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSeenOnboardingKey, true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return IntroductionScreen(
      globalBackgroundColor: Colors.white,

      // ── Boutons ─────────────────────────────────────────────
      showSkipButton: true,
      skip: Text(
        "Passer",
        style: TextStyle(
          color: primaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      next: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.arrow_forward, color: primaryColor, size: 24),
      ),
      done: FittedBox(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Text(
            "Commencer",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),

      onSkip: () => _finish(context),
      onDone: () => _finish(context),

      // ── Contrôles en bas — remonter les boutons ─────────────
      controlsMargin: EdgeInsets.only(
        bottom: bottomPadding + 16,
      ),
      controlsPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),

      // ── Dots ────────────────────────────────────────────────
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(20, 8),
        spacing: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.grey.shade300,
        activeColor: primaryColor,
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
        ),
      ),

      // ── Pages ───────────────────────────────────────────────
      pages: [
        _buildPage(
          context: context,
          theme: theme,
          title: "Bienvenue sur City Guide",
          body:
          "Explorez Kinshasa autrement : restaurants, hôtels, sorties, événements et bonnes adresses au même endroit.",
          imagePath: "assets/images/onboarding/onboarding_1.png",
        ),
        _buildPage(
          context: context,
          theme: theme,
          title: "Gardez vos meilleurs spots",
          body:
          "Ajoutez vos lieux préférés en favoris et retrouvez-les en un clic, quand vous en avez besoin.",
          imagePath: "assets/images/onboarding/onboarding_2.png",
        ),
        _buildPage(
          context: context,
          theme: theme,
          title: "Partagez votre expérience",
          body:
          "Notez les lieux, publiez vos photos et aidez la communauté à découvrir le meilleur de Kin.",
          imagePath: "assets/images/onboarding/onboarding_3.png",
        ),
      ],
    );
  }

  PageViewModel _buildPage({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required String body,
    required String imagePath,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Adapter la taille de l'image selon la hauteur de l'écran
    final isSmallScreen = screenHeight < 700;

    return PageViewModel(
      title: title,
      body: body,
      image: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: isSmallScreen ? screenHeight * 0.35 : screenHeight * 0.42,
          ),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.image_not_supported_outlined,
              size: isSmallScreen ? 80 : 120,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ),
      ),
      decoration: PageDecoration(
        titleTextStyle: TextStyle(
          fontSize: isSmallScreen ? 20 : 24,
          fontWeight: FontWeight.bold,
          color: theme.textTheme.titleLarge?.color,
          height: 1.3,
        ),
        bodyTextStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          height: 1.5,
        ),
        bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
        imagePadding: EdgeInsets.only(
          top: isSmallScreen ? 24 : 40,
          bottom: 8,
        ),
        // Ratio image/texte mieux équilibré pour laisser de la place aux boutons
        imageFlex: isSmallScreen ? 3 : 4,
        bodyFlex: 2,
        imageAlignment: Alignment.center,
        bodyAlignment: Alignment.center,
        pageColor: Colors.white,
      ),
    );
  }
}
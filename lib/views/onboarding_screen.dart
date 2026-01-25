// lib/views/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  // Clé publique pour vérifier si l'onboarding a été vu
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

    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      showSkipButton: true,
      skip: Text(
        "Passer",
        style: TextStyle(color: primaryColor),
      ),
      next: Icon(Icons.arrow_forward, color: primaryColor),
      done: Text(
        "Commencer",
        style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor),
      ),
      onSkip: () => _finish(context),
      onDone: () => _finish(context),
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(18, 8),
        color: Colors.grey.shade300,
        activeColor: primaryColor,
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
        ),
      ),
      pages: [
        PageViewModel(
          title: "Bienvenue sur Kin City Guide",
          body: "Découvrez les meilleurs lieux : restos, hôtels, événements et plus.",
          image: _buildImage("assets/images/onboarding_1.png", context),
          decoration: _buildDecoration(theme),
        ),
        PageViewModel(
          title: "Sauvegardez vos favoris",
          body: "Gardez une liste personnelle des lieux que vous aimez.",
          image: _buildImage("assets/images/onboarding_2.png", context),
          decoration: _buildDecoration(theme),
        ),
        PageViewModel(
          title: "Partagez vos avis",
          body: "Notez les lieux et ajoutez des photos pour aider la communauté.",
          image: _buildImage("assets/images/onboarding_3.png", context),
          decoration: _buildDecoration(theme),
        ),
      ],
    );
  }

  Widget _buildImage(String path, BuildContext context) {
    return Center(
      child: Image.asset(
        path,
        width: 280,
        errorBuilder: (_, __, ___) => Icon(
          Icons.image_not_supported_outlined,
          size: 120,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
    );
  }

  PageDecoration _buildDecoration(ThemeData theme) {
    return PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: theme.textTheme.titleLarge?.color,
      ),
      bodyTextStyle: TextStyle(
        fontSize: 15,
        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
      ),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 16),
      imagePadding: const EdgeInsets.only(top: 40),
      pageColor: Colors.white,
    );
  }
}
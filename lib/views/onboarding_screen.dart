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
      next: Icon(Icons.arrow_forward, color: primaryColor,),
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: primaryColor, // ✅ vert
          borderRadius: BorderRadius.circular(15), // ✅ coins arrondis
        ),
        child: const Text(
          "Commencer",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
          body: "Explorez Kinshasa autrement : restaurants, hôtels, sorties, événements et bonnes adresses au même endroit.",
          image: _buildImage("assets/images/onboarding/onboarding_1.png", context),
          decoration: _buildDecoration(theme),
        ),
        PageViewModel(
          title: "Gardez vos meilleurs spots",
          body: "Ajoutez vos lieux préférés en favoris et retrouvez-les en un clic, quand vous en avez besoin.",
          image: _buildImage("assets/images/onboarding/onboarding_2.png", context),
          decoration: _buildDecoration(theme),
        ),
        PageViewModel(
          title: "Partagez votre expérience",
          body: "Notez les lieux, publiez vos photos et aidez la communauté à découvrir le meilleur de Kin.",
          image: _buildImage("assets/images/onboarding/onboarding_3.png", context),
          decoration: _buildDecoration(theme),
        ),
      ],
    );
  }

  Widget _buildImage(String path, BuildContext context) {
    return Center(
      child: Image.asset(
        path,
        width: 480,

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
        height: 0.3, // ✅ réduit la hauteur de ligne du titre
      ),
      bodyTextStyle: TextStyle(
        fontSize: 15,
        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
        height: 1.2, // ✅ réduit la hauteur de ligne du body
      ),

      // ✅ Réduit le padding global du texte
      bodyPadding: const EdgeInsets.symmetric(horizontal: 6),

      // ✅ Réduit l’espace autour de l’image + la place en haut
      imagePadding: const EdgeInsets.only(top: 15),

      // ✅ Réduit l’espace entre image -> texte (si supported par votre package)
      //descriptionPadding: const EdgeInsets.only(top: 6),

      // ✅ Agrandit l’image (plus de place à l’image)
      imageFlex: 5,
      bodyFlex: 2,

      // ✅ Centre l’image
      imageAlignment: Alignment.center,

      pageColor: Colors.white,
    );

  }
}
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

 // si tu l'as séparé; sinon, adapte l'import
import '../main.dart';   // si AuthGate est dans main.dart, tu peux importer main.dart, ou mieux: déplacer AuthGate dans un fichier.

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _kSeenOnboardingKey = 'seen_onboarding';

  Future<void> _finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenOnboardingKey, true);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      showSkipButton: true,
      skip: const Text("Passer"),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Commencer", style: TextStyle(fontWeight: FontWeight.w600)),

      onSkip: () => _finish(context),
      onDone: () => _finish(context),

      dotsDecorator: const DotsDecorator(
        size: Size(8, 8),
        activeSize: Size(18, 8),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
        ),
      ),

      pages: [
        PageViewModel(
          title: "Bienvenue sur Kin City Guide",
          body: "Découvrez les meilleurs lieux : restos, hôtels, événements et plus.",
          image: _image("assets/images/onboarding_1.png"),
          decoration: _decoration(),
        ),
        PageViewModel(
          title: "Sauvegardez vos favoris",
          body: "Gardez une liste personnelle des lieux que vous aimez.",
          image: _image("assets/images/onboarding_2.png"),
          decoration: _decoration(),
        ),
        PageViewModel(
          title: "Partagez vos avis",
          body: "Notez les lieux et ajoutez des photos pour aider la communauté.",
          image: _image("assets/images/onboarding_3.png"),
          decoration: _decoration(),
        ),
      ],
    );
  }

  static Widget _image(String path) {
    return Center(child: Image.asset(path, width: 280));
  }

  static PageDecoration _decoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      bodyTextStyle: TextStyle(fontSize: 15),
      bodyPadding: EdgeInsets.symmetric(horizontal: 16),
      imagePadding: EdgeInsets.only(top: 40),
      pageColor: Colors.white,
    );
  }
}

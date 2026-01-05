import 'package:firebase_core/firebase_core.dart';

/// Classe générée automatiquement par FlutterFire pour définir les
/// différentes options Firebase par plateforme.  Cette version est
/// fournie à titre d’exemple et utilise des valeurs fictives afin de
/// permettre à l’application de se compiler.  **Remplacez ces
/// valeurs par celles générées par la commande** `flutterfire
/// configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Les champs ci‑dessous doivent être complétés avec les valeurs
    // propres à votre projet Firebase.  Sans ces valeurs, l’app
    // échouera à l’initialisation.  Consultez la documentation
    // FlutterFire pour générer automatiquement ce fichier.
    return const FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
      projectId: 'YOUR_PROJECT_ID',
      storageBucket: 'YOUR_STORAGE_BUCKET',
    );
  }
}
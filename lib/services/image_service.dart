import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

/// Service pour gérer les opérations sur les images
/// - Compression en JPEG optimisé
/// - Upload vers Firebase Storage
/// - Suppression d'images
class ImageService {
  static const int maxWidth = 1920;
  static const int jpegQuality = 85;

  /// Compresse une image en JPEG et retourne les bytes
  static Future<Uint8List> compressToJPEG(File imageFile) async {
    try {
      // Lire le fichier
      final bytes = await imageFile.readAsBytes();

      // Décoder l'image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      // Redimensionner si nécessaire
      final resized = image.width > maxWidth
          ? img.copyResize(image, width: maxWidth)
          : image;

      // Convertir en JPEG avec compression
      final jpegBytes = img.encodeJpg(resized, quality: jpegQuality);

      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      throw Exception('Erreur lors de la compression: $e');
    }
  }

  /// Upload une image vers Firebase Storage
  /// Retourne l'URL de téléchargement
  static Future<String> uploadImage({
    required File imageFile,
    required String category,
    required int index,
  }) async {
    try {
      // Compresser l'image
      final jpegBytes = await compressToJPEG(imageFile);

      // Générer un nom de fichier unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${category}_${timestamp}_$index.jpg';

      // Référence Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('$category/$fileName');

      // Upload avec métadonnées
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'category': category,
        },
      );

      await ref.putData(jpegBytes, metadata);

      // Obtenir l'URL de téléchargement
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Erreur lors de l\'upload: $e');
    }
  }

  /// Upload plusieurs images
  /// Retourne une liste d'URLs
  static Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    required String category,
    void Function(int current, int total)? onProgress,
  }) async {
    final List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i + 1, imageFiles.length);

      final url = await uploadImage(
        imageFile: imageFiles[i],
        category: category,
        index: i,
      );

      urls.add(url);
    }

    return urls;
  }

  /// Supprime une image de Firebase Storage à partir de son URL
  static Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // L'image n'existe peut-être plus
      print('Erreur lors de la suppression: $e');
    }
  }

  /// Supprime plusieurs images
  static Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImageByUrl(url);
    }
  }

  /// Obtient la taille d'une image en bytes
  static Future<int> getImageSize(File imageFile) async {
    return await imageFile.length();
  }

  /// Obtient les dimensions d'une image
  static Future<Map<String, int>> getImageDimensions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      return {'width': 0, 'height': 0};
    }

    return {
      'width': image.width,
      'height': image.height,
    };
  }

  /// Valide si un fichier est une image valide
  static Future<bool> isValidImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }

  /// Crée une thumbnail (miniature) d'une image
  static Future<Uint8List> createThumbnail(
      File imageFile, {
        int maxSize = 300,
      }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      // Créer une miniature carrée
      final thumbnail = img.copyResizeCropSquare(image, size: maxSize);

      // Encoder en JPEG
      final jpgBytes = img.encodeJpg(thumbnail, quality: jpegQuality);

      return Uint8List.fromList(jpgBytes);
    } catch (e) {
      throw Exception('Erreur lors de la création de la miniature: $e');
    }
  }

  /// Upload une image avec sa thumbnail
  static Future<Map<String, String>> uploadImageWithThumbnail({
    required File imageFile,
    required String category,
    required int index,
  }) async {
    try {
      // Upload image principale
      final imageUrl = await uploadImage(
        imageFile: imageFile,
        category: category,
        index: index,
      );

      // Créer et upload thumbnail
      final thumbnailBytes = await createThumbnail(imageFile);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailFileName = '${category}_${timestamp}_${index}_thumb.jpg';

      final thumbnailRef = FirebaseStorage.instance
          .ref()
          .child('$category/thumbnails/$thumbnailFileName');

      await thumbnailRef.putData(thumbnailBytes);
      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      return {
        'image': imageUrl,
        'thumbnail': thumbnailUrl,
      };
    } catch (e) {
      throw Exception('Erreur lors de l\'upload avec thumbnail: $e');
    }
  }
}
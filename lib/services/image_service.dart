import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

/// Service pour gérer les opérations sur les images
/// - Compression en JPEG optimisé
/// - Upload vers Firebase Storage
/// - Suppression d'images
class ImageService {
  static const int maxWidth = 1920;
  static const int jpegQuality = 85;

  /// Compresse des bytes d'image en JPEG
  static Future<Uint8List> compressBytesToJPEG(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      final resized = image.width > maxWidth
          ? img.copyResize(image, width: maxWidth)
          : image;

      final jpegBytes = img.encodeJpg(resized, quality: jpegQuality);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      throw Exception('Erreur lors de la compression: $e');
    }
  }

  /// Compresse une image File en JPEG (mobile uniquement)
  static Future<Uint8List> compressToJPEG(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return compressBytesToJPEG(bytes);
  }

  /// Upload une image depuis un File (mobile)
  static Future<String> uploadImage({
    required File imageFile,
    required String category,
    required int index,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return uploadImageBytes(
        bytes: bytes,
        category: category,
        index: index,
      );
    } catch (e) {
      throw Exception('Erreur lors de l\'upload: $e');
    }
  }

  /// Upload une image depuis des bytes (web + mobile)
  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String category,
    required int index,
  }) async {
    try {
      // Sur web : pas de compression (dart:io indisponible)
      // Sur mobile : compression normale
      final Uint8List finalBytes;
      if (kIsWeb) {
        finalBytes = bytes;
      } else {
        finalBytes = await compressBytesToJPEG(bytes);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${category}_${timestamp}_$index.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('$category/$fileName');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'category': category,
        },
      );

      await ref.putData(finalBytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erreur lors de l\'upload: $e');
    }
  }

  /// Upload plusieurs images depuis des Files (mobile)
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

  /// Upload plusieurs images depuis des bytes (web + mobile)
  static Future<List<String>> uploadMultipleImageBytes({
    required List<Uint8List> imageBytesList,
    required String category,
    void Function(int current, int total)? onProgress,
  }) async {
    final List<String> urls = [];

    for (int i = 0; i < imageBytesList.length; i++) {
      onProgress?.call(i + 1, imageBytesList.length);

      final url = await uploadImageBytes(
        bytes: imageBytesList[i],
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
      debugPrint('Erreur lors de la suppression: $e');
    }
  }

  /// Supprime plusieurs images
  static Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImageByUrl(url);
    }
  }

  /// Obtient la taille d'une image en bytes (mobile uniquement)
  static Future<int> getImageSize(File imageFile) async {
    return await imageFile.length();
  }

  /// Obtient les dimensions d'une image depuis des bytes (web + mobile)
  static Map<String, int> getImageDimensionsFromBytes(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return {'width': 0, 'height': 0};
    }
    return {
      'width': image.width,
      'height': image.height,
    };
  }

  /// Obtient les dimensions d'une image (mobile uniquement)
  static Future<Map<String, int>> getImageDimensions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return getImageDimensionsFromBytes(bytes);
  }

  /// Valide si des bytes sont une image valide (web + mobile)
  static bool isValidImageBytes(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }

  /// Valide si un fichier est une image valide (mobile uniquement)
  static Future<bool> isValidImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return isValidImageBytes(bytes);
    } catch (e) {
      return false;
    }
  }

  /// Crée une thumbnail depuis des bytes (web + mobile)
  static Future<Uint8List> createThumbnailFromBytes(
      Uint8List bytes, {
        int maxSize = 300,
      }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      final thumbnail = img.copyResizeCropSquare(image, size: maxSize);
      final jpgBytes = img.encodeJpg(thumbnail, quality: jpegQuality);
      return Uint8List.fromList(jpgBytes);
    } catch (e) {
      throw Exception('Erreur lors de la création de la miniature: $e');
    }
  }

  /// Crée une thumbnail depuis un File (mobile uniquement)
  static Future<Uint8List> createThumbnail(
      File imageFile, {
        int maxSize = 300,
      }) async {
    final bytes = await imageFile.readAsBytes();
    return createThumbnailFromBytes(bytes, maxSize: maxSize);
  }

  /// Upload une image avec sa thumbnail (mobile)
  static Future<Map<String, String>> uploadImageWithThumbnail({
    required File imageFile,
    required String category,
    required int index,
  }) async {
    final bytes = await imageFile.readAsBytes();
    return uploadImageBytesWithThumbnail(
      bytes: bytes,
      category: category,
      index: index,
    );
  }

  /// Upload une image avec sa thumbnail depuis des bytes (web + mobile)
  static Future<Map<String, String>> uploadImageBytesWithThumbnail({
    required Uint8List bytes,
    required String category,
    required int index,
  }) async {
    try {
      final imageUrl = await uploadImageBytes(
        bytes: bytes,
        category: category,
        index: index,
      );

      final thumbnailBytes = await createThumbnailFromBytes(bytes);
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
// lib/controllers/ads_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ad_model.dart';
import '../services/ad_service.dart';

final adsServiceProvider = Provider<AdsService>((ref) {
  return AdsService();
});

/// Annonces actives (bannière de la home), en temps réel.
final activeAdsProvider = StreamProvider<List<AdModel>>((ref) {
  final service = ref.watch(adsServiceProvider);
  return service.watchActiveAds();
});

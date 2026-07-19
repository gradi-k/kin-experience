// lib/data/kinshasa_zones.dart
//
// Les 24 communes de Kinshasa avec les coordonnées approximatives de leur
// centre. Sert de source de suggestions hors-ligne : la couverture
// OpenStreetMap/Nominatim est faible à Kinshasa.

class KinshasaZone {
  final String nom;
  final double latitude;
  final double longitude;

  const KinshasaZone(this.nom, this.latitude, this.longitude);
}

const List<KinshasaZone> kinshasaZones = [
  KinshasaZone('Bandalungwa', -4.3439, 15.2831),
  KinshasaZone('Barumbu', -4.3103, 15.3231),
  KinshasaZone('Bumbu', -4.3833, 15.2833),
  KinshasaZone('Gombe', -4.3054, 15.2938),
  KinshasaZone('Kalamu', -4.3436, 15.3125),
  KinshasaZone('Kasa-Vubu', -4.3372, 15.3006),
  KinshasaZone('Kimbanseke', -4.4167, 15.4333),
  KinshasaZone('Kinshasa (commune)', -4.3167, 15.3167),
  KinshasaZone('Kintambo', -4.3283, 15.2597),
  KinshasaZone('Kisenso', -4.4167, 15.3667),
  KinshasaZone('Lemba', -4.3894, 15.3336),
  KinshasaZone('Limete', -4.3550, 15.3383),
  KinshasaZone('Lingwala', -4.3181, 15.3006),
  KinshasaZone('Makala', -4.3833, 15.3000),
  KinshasaZone('Maluku', -4.0833, 15.5500),
  KinshasaZone('Masina', -4.3833, 15.4000),
  KinshasaZone('Matete', -4.3872, 15.3489),
  KinshasaZone('Mont-Ngafula', -4.4500, 15.2833),
  KinshasaZone('Ndjili', -4.4000, 15.3719),
  KinshasaZone('Ngaba', -4.3717, 15.3169),
  KinshasaZone('Ngaliema', -4.3500, 15.2333),
  KinshasaZone('Ngiri-Ngiri', -4.3486, 15.2958),
  KinshasaZone('Nsele', -4.3167, 15.5167),
  KinshasaZone('Selembao', -4.3667, 15.2667),
];

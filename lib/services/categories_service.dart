import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_config.dart';

/// Accès à la collection `categories`.
///
/// L'id du document est la clé métier ([CategoryConfig.key]) : elle est
/// recopiée dans `places/{id}.categoryKey`. Elle est donc fixée à la création
/// et jamais modifiée — [updateCategory] ne la touche pas.
class CategoriesService {
  final FirebaseFirestore _db;

  CategoriesService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('categories');

  /// Toutes les catégories, y compris désactivées (admin). Triées par `order`.
  ///
  /// Le tri est fait côté client : la collection compte quelques dizaines de
  /// documents au plus, et ça évite d'imposer un index composite.
  Stream<List<CategoryConfig>> watchAll() {
    return _col.snapshots().map(_mapAndSort);
  }

  /// Catégories visibles dans l'app publique.
  Stream<List<CategoryConfig>> watchEnabled() {
    return _col.where('enabled', isEqualTo: true).snapshots().map(_mapAndSort);
  }

  Future<List<CategoryConfig>> fetchAll() async {
    final snap = await _col.get();
    return _mapAndSort(snap);
  }

  Future<CategoryConfig?> fetchByKey(String key) async {
    final doc = await _col.doc(key).get();
    if (!doc.exists) return null;
    return CategoryConfig.fromMap(doc.data() ?? {}, doc.id);
  }

  List<CategoryConfig> _mapAndSort(QuerySnapshot<Map<String, dynamic>> snap) {
    final out = snap.docs
        .map((d) => CategoryConfig.fromMap(d.data(), d.id))
        .toList();
    out.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
    });
    return out;
  }

  /// Crée une catégorie. Échoue si la clé est déjà prise, pour éviter
  /// d'écraser silencieusement une catégorie existante et ses lieux.
  Future<void> createCategory(CategoryConfig category) async {
    final key = category.key.trim();
    if (key.isEmpty) {
      throw ArgumentError('La clé de la catégorie ne peut pas être vide.');
    }

    final doc = _col.doc(key);
    if ((await doc.get()).exists) {
      throw StateError('La catégorie "$key" existe déjà.');
    }

    await doc.set({
      ...category.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Met à jour une catégorie. La clé (= id du doc) n'est pas modifiable.
  Future<void> updateCategory(CategoryConfig category) async {
    await _col.doc(category.key).update({
      ...category.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setEnabled(String key, bool enabled) {
    return _col.doc(key).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Réordonne les catégories en une écriture atomique.
  Future<void> reorder(List<String> keysInOrder) async {
    final batch = _db.batch();
    for (var i = 0; i < keysInOrder.length; i++) {
      batch.update(_col.doc(keysInOrder[i]), {
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Nombre de lieux rattachés à une catégorie.
  ///
  /// Utilisé pour avertir avant suppression. Passe par `count()` : le coût est
  /// facturé à l'index, pas au nombre de documents lus.
  Future<int> countPlaces(String key) async {
    final snap = await _db
        .collection('places')
        .where('categoryKey', isEqualTo: key)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Supprime définitivement une catégorie.
  ///
  /// Refuse tant que des lieux y sont rattachés : ils deviendraient
  /// inatteignables (plus aucun écran ne liste leur `categoryKey`). Désactiver
  /// via [setEnabled] est la façon sûre de retirer une catégorie de l'app.
  Future<void> deleteCategory(String key) async {
    final count = await countPlaces(key);
    if (count > 0) {
      throw StateError(
        'Impossible de supprimer "$key" : $count lieu(x) y sont rattachés. '
        'Désactivez la catégorie ou déplacez ses lieux d\'abord.',
      );
    }
    await _col.doc(key).delete();
  }
}

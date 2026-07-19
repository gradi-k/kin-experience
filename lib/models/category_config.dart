import 'package:flutter/material.dart';

import '../utils/category_icons.dart';
import 'field_def.dart';
import 'model_helpers.dart';

/// Une catégorie de lieux, configurée depuis l'admin et stockée dans
/// `categories/{key}`.
///
/// L'[key] du document EST la clé métier : elle est recopiée dans
/// `places/{id}.categoryKey`. La renommer orpheline les lieux — l'admin doit
/// donc la rendre non modifiable après création.
class CategoryConfig {
  /// Identifiant stable (= id du document). Ex: "pharmacie".
  final String key;

  /// Libellés par locale ('fr', 'en'). Voir [labelFor].
  final Map<String, String> label;

  /// Nom d'icône résolu via [CategoryIcons]. Ex: "local_pharmacy".
  final String iconName;

  /// Ordre d'affichage (home, filtres, admin). Croissant.
  final int order;

  /// Une catégorie désactivée disparaît de l'app publique mais conserve ses
  /// lieux — c'est la façon sûre de « supprimer » une catégorie.
  final bool enabled;

  /// Champs personnalisés, stockés dans `places/{id}.extras`.
  final List<FieldDef> fields;

  /// Couleur d'accent optionnelle (ARGB). Repli sur la couleur primaire du thème.
  final int? colorValue;

  /// Libellé du bouton d'action principal de la fiche détail, par locale
  /// (ex: {fr: "Réserver"} pour un hôtel, {fr: "Acheter un billet"} pour un
  /// événement). Vide ⇒ repli générique, voir [ctaLabelFor].
  final Map<String, String> ctaLabel;

  /// Icône du bouton d'action principal, résolue via [CategoryIcons].
  final String? ctaIconName;

  const CategoryConfig({
    required this.key,
    required this.label,
    this.iconName = CategoryIcons.fallbackName,
    this.order = 0,
    this.enabled = true,
    this.fields = const [],
    this.colorValue,
    this.ctaLabel = const {},
    this.ctaIconName,
  });

  IconData get icon => CategoryIcons.resolve(iconName);

  Color? get color => colorValue == null ? null : Color(colorValue!);

  /// Libellé du bouton d'action, avec repli sur [fallback] si la catégorie
  /// n'en déclare pas.
  String ctaLabelFor(String locale, {required String fallback}) {
    final exact = ctaLabel[locale];
    if (exact != null && exact.isNotEmpty) return exact;
    final fr = ctaLabel['fr'];
    if (fr != null && fr.isNotEmpty) return fr;
    return fallback;
  }

  /// Icône du bouton d'action ; repli sur celle de la catégorie.
  IconData get ctaIcon =>
      ctaIconName == null ? icon : CategoryIcons.resolve(ctaIconName);

  /// Teinte du marqueur sur la carte, dans [0, 360).
  ///
  /// Dérivée de [color] si la catégorie en déclare une. Sinon, calculée depuis
  /// la clé : deux catégories distinctes obtiennent des teintes distinctes et
  /// stables, sans configuration — le nombre de catégories n'étant plus borné,
  /// une table de couleurs en dur ne tiendrait pas.
  double get markerHue {
    final c = color;
    if (c != null) return HSLColor.fromColor(c).hue;

    // Nombre d'or : disperse les teintes au lieu de les regrouper.
    final h = key.hashCode.abs() % 360;
    return (h * 137.508) % 360;
  }

  /// Libellé pour [locale], avec repli sur le français, puis sur [key].
  String labelFor(String locale) {
    final exact = label[locale];
    if (exact != null && exact.isNotEmpty) return exact;
    final fr = label['fr'];
    if (fr != null && fr.isNotEmpty) return fr;
    return label.isNotEmpty ? label.values.first : key;
  }

  /// Champs triés pour l'affichage du formulaire et de la fiche.
  List<FieldDef> get sortedFields {
    final out = [...fields];
    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }

  factory CategoryConfig.fromMap(Map<String, dynamic> map, String id) {
    final rawFields = map['fields'];
    final fields = <FieldDef>[];
    if (rawFields is List) {
      for (final f in rawFields) {
        if (f is Map) {
          final def = FieldDef.fromMap(ModelHelpers.parseMap(f));
          // Un champ sans clé est inexploitable : ses valeurs ne pourraient
          // être ni écrites ni relues dans `extras`.
          if (def.key.isNotEmpty) fields.add(def);
        }
      }
    }

    return CategoryConfig(
      key: id,
      label: ModelHelpers.parseLocalizedString(map['label']),
      iconName: (map['icon'] ?? CategoryIcons.fallbackName).toString(),
      order: ModelHelpers.parseInt(map['order']),
      enabled: ModelHelpers.parseBool(map['enabled'], defaultValue: true),
      fields: fields,
      colorValue: map['color'] == null ? null : ModelHelpers.parseInt(map['color']),
      ctaLabel: ModelHelpers.parseLocalizedString(map['ctaLabel']),
      ctaIconName: map['ctaIcon']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'icon': iconName,
      'order': order,
      'enabled': enabled,
      'fields': fields.map((f) => f.toMap()).toList(),
      if (colorValue != null) 'color': colorValue,
      if (ctaLabel.isNotEmpty) 'ctaLabel': ctaLabel,
      if (ctaIconName != null) 'ctaIcon': ctaIconName,
    };
  }

  CategoryConfig copyWith({
    String? key,
    Map<String, String>? label,
    String? iconName,
    int? order,
    bool? enabled,
    List<FieldDef>? fields,
    int? colorValue,
    Map<String, String>? ctaLabel,
    String? ctaIconName,
  }) {
    return CategoryConfig(
      key: key ?? this.key,
      label: label ?? this.label,
      iconName: iconName ?? this.iconName,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      fields: fields ?? this.fields,
      colorValue: colorValue ?? this.colorValue,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaIconName: ctaIconName ?? this.ctaIconName,
    );
  }
}

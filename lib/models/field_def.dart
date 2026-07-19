import 'model_helpers.dart';

/// Type d'un champ déclaré par une catégorie.
///
/// La valeur sérialisée en Firestore est [key] (ex: "bool"). Toute valeur
/// inconnue retombe sur [FieldType.text] pour qu'un champ ajouté par une
/// version future de l'admin reste éditable (en texte) sur une app ancienne.
enum FieldType {
  text,
  multiline,
  number,
  bool,
  select,
  multiselect,
  date,
  phone,
  url;

  static FieldType fromKey(String? raw) {
    final k = (raw ?? '').trim().toLowerCase();
    for (final t in FieldType.values) {
      if (t.name == k) return t;
    }
    return FieldType.text;
  }
}

/// Définition d'un champ personnalisé d'une catégorie.
///
/// Les valeurs saisies sont stockées dans `places/{id}.extras[key]`.
class FieldDef {
  /// Clé de stockage dans `extras`. Stable : la renommer orpheline les données.
  final String key;

  /// Libellés par locale ('fr', 'en'). Voir [labelFor].
  final Map<String, String> label;

  final FieldType type;
  final bool required;

  /// Choix possibles pour [FieldType.select] / [FieldType.multiselect].
  final List<String> options;

  /// Ordre d'affichage dans le formulaire admin et la fiche détail.
  final int order;

  /// Texte d'aide affiché sous le champ.
  final String? hint;

  const FieldDef({
    required this.key,
    required this.label,
    this.type = FieldType.text,
    this.required = false,
    this.options = const [],
    this.order = 0,
    this.hint,
  });

  /// Libellé pour [locale], avec repli sur le français, puis sur [key].
  String labelFor(String locale) {
    final exact = label[locale];
    if (exact != null && exact.isNotEmpty) return exact;
    final fr = label['fr'];
    if (fr != null && fr.isNotEmpty) return fr;
    return label.isNotEmpty ? label.values.first : key;
  }

  factory FieldDef.fromMap(Map<String, dynamic> map) {
    return FieldDef(
      key: (map['key'] ?? '').toString(),
      label: ModelHelpers.parseLocalizedString(map['label']),
      type: FieldType.fromKey(map['type']?.toString()),
      required: ModelHelpers.parseBool(map['required']),
      options: ModelHelpers.parseStringList(map['options']),
      order: ModelHelpers.parseInt(map['order']),
      hint: map['hint']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'type': type.name,
      'required': required,
      'options': options,
      'order': order,
      if (hint != null && hint!.isNotEmpty) 'hint': hint,
    };
  }

  FieldDef copyWith({
    String? key,
    Map<String, String>? label,
    FieldType? type,
    bool? required,
    List<String>? options,
    int? order,
    String? hint,
  }) {
    return FieldDef(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
      order: order ?? this.order,
      hint: hint ?? this.hint,
    );
  }
}

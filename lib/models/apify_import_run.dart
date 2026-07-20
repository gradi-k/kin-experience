// lib/models/apify_import_run.dart
import 'model_helpers.dart';

/// Compteurs d'un import Apify terminé.
class ApifyImportCounts {
  final int fetched;
  final int created;
  final int updated;
  final int skipped;

  const ApifyImportCounts({
    this.fetched = 0,
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
  });

  factory ApifyImportCounts.fromMap(Map<String, dynamic> map) {
    return ApifyImportCounts(
      fetched: ModelHelpers.parseInt(map['fetched']),
      created: ModelHelpers.parseInt(map['created']),
      updated: ModelHelpers.parseInt(map['updated']),
      skipped: ModelHelpers.parseInt(map['skipped']),
    );
  }
}

/// Un run d'import Apify, suivi dans `apify_imports/{runId}`.
class ApifyImportRun {
  final String id;
  final String? categoryKey;
  final String? query;
  final String? commune;
  final int? maxItems;

  /// 'running' | 'done' | 'failed'.
  final String status;
  final String? error;
  final ApifyImportCounts? counts;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const ApifyImportRun({
    required this.id,
    this.categoryKey,
    this.query,
    this.commune,
    this.maxItems,
    this.status = 'running',
    this.error,
    this.counts,
    this.startedAt,
    this.finishedAt,
  });

  factory ApifyImportRun.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      // Timestamp Firestore ou DateTime déjà converti.
      try {
        final toDate = (v as dynamic).toDate;
        if (toDate != null) return toDate() as DateTime;
      } catch (_) {}
      if (v is DateTime) return v;
      return null;
    }

    final rawCounts = map['counts'];
    return ApifyImportRun(
      id: id,
      categoryKey: map['categoryKey']?.toString(),
      query: map['query']?.toString(),
      commune: map['commune']?.toString(),
      maxItems: map['maxItems'] == null ? null : ModelHelpers.parseInt(map['maxItems']),
      status: (map['status'] ?? 'running').toString(),
      error: map['error']?.toString(),
      counts: rawCounts is Map
          ? ApifyImportCounts.fromMap(ModelHelpers.parseMap(rawCounts))
          : null,
      startedAt: parseDate(map['startedAt']),
      finishedAt: parseDate(map['finishedAt']),
    );
  }
}

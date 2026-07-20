import 'package:flutter_test/flutter_test.dart';
import 'package:cityguide/models/apify_import_run.dart';

void main() {
  test('fromMap tolère les champs manquants', () {
    final run = ApifyImportRun.fromMap(const {}, 'r1');
    expect(run.id, 'r1');
    expect(run.status, 'running');
    expect(run.counts, isNull);
  });

  test('fromMap lit les compteurs', () {
    final run = ApifyImportRun.fromMap(const {
      'status': 'done',
      'query': 'restaurants Gombe Kinshasa',
      'counts': {'fetched': 10, 'created': 6, 'updated': 3, 'skipped': 1},
    }, 'r2');
    expect(run.status, 'done');
    expect(run.query, 'restaurants Gombe Kinshasa');
    expect(run.counts!.created, 6);
    expect(run.counts!.fetched, 10);
  });

  test('fromMap lit le message d\'erreur', () {
    final run = ApifyImportRun.fromMap(const {
      'status': 'failed',
      'error': 'Run Apify: ACTOR.RUN.FAILED',
    }, 'r3');
    expect(run.status, 'failed');
    expect(run.error, 'Run Apify: ACTOR.RUN.FAILED');
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:diakont/data/cloud/cloud_store.dart';
import 'package:diakont/data/local/local_db.dart';
import 'package:diakont/data/models/models.dart';
import 'package:diakont/data/repositories/repositories.dart';
import 'package:diakont/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Nube falsa en memoria (simula la carpeta privada de Drive/OneDrive).
class FakeStore implements CloudStore {
  final files = <String, Uint8List>{};
  final versions = <String, int>{};

  @override
  Future<List<RemoteFile>> list() async => [
    for (final n in files.keys)
      RemoteFile(id: n, name: n, version: '${versions[n]}'),
  ];

  @override
  Future<Uint8List> download(RemoteFile file) async => files[file.id]!;

  @override
  Future<void> upload(
    String name,
    Uint8List bytes, {
    RemoteFile? existing,
  }) async {
    files[name] = bytes;
    versions[name] = (versions[name] ?? 0) + 1;
  }
}

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  const account = 'google_123';

  setUp(() => tmp = Directory.systemTemp.createTempSync('dk_sync_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(LocalDb, SyncService)> device(String name, FakeStore cloud) async {
    final db = await LocalDb.openWith(
      databaseFactoryFfi,
      '${tmp.path}/$name.db',
      account,
    );
    return (db, SyncService(db: db, store: cloud));
  }

  Expense expense(String concept, {String? id, DateTime? updated}) => Expense(
    id: id ?? newId(),
    userId: account,
    date: DateTime(2026, 11, 22),
    concept: concept,
    subtotalCents: 1000,
    vatCents: 220,
    totalCents: 1220,
    vatRateBp: 2200,
    vatIncluded: true,
    createdAt: DateTime.utc(2026),
    updatedAt: updated ?? DateTime.utc(2026),
  );

  test(
    'celular y PC convergen; categorías por defecto no se duplican',
    () async {
      final cloud = FakeStore();
      final (dbA, syncA) = await device('celular', cloud);
      final (dbB, syncB) = await device('pc', cloud);
      final repoA = ExpenseRepository(dbA, account);
      final repoB = ExpenseRepository(dbB, account);

      await repoA.save(expense('Factura UTE'));
      await syncA.syncNow();
      await syncB.syncNow();
      expect((await repoB.watchAll().first).map((e) => e.concept), [
        'Factura UTE',
      ]);

      // Las 7 categorías por defecto se fusionan (mismos ids en ambos equipos).
      final cats = await CategoryRepository(dbB, account).watchAll().first;
      expect(cats.length, 7);

      // La PC edita y el celular recibe el cambio.
      final e = (await repoB.watchAll().first).single;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repoB.save(expense('Factura UTE octubre', id: e.id));
      await syncB.syncNow();
      await syncA.syncNow();
      expect(
        (await repoA.watchAll().first).single.concept,
        'Factura UTE octubre',
      );

      // Borrado en el celular: desaparece en la PC.
      await repoA.delete(e.id);
      await syncA.syncNow();
      await syncB.syncNow();
      expect(await repoB.watchAll().first, isEmpty);

      expect(syncA.status.phase, SyncPhase.idle);
      expect(syncA.status.pending, 0);
      await dbA.close();
      await dbB.close();
    },
  );

  test('offline en ambos: gana la edición más reciente', () async {
    final cloud = FakeStore();
    final (dbA, syncA) = await device('a', cloud);
    final (dbB, syncB) = await device('b', cloud);
    final id = newId();
    // Ambos editan el mismo gasto "sin conexión"; B lo hace después.
    await dbA.raw.insert('expenses', {
      ...expense('Versión vieja', id: id).toRow(),
      'updated_at': '2026-11-22T10:00:00.000Z',
      'dirty': 1,
    });
    await dbB.raw.insert('expenses', {
      ...expense('Versión nueva', id: id).toRow(),
      'updated_at': '2026-11-22T11:00:00.000Z',
      'dirty': 1,
    });
    await syncA.syncNow();
    await syncB.syncNow();
    await syncA.syncNow();
    for (final db in [dbA, dbB]) {
      final list = await ExpenseRepository(db, account).watchAll().first;
      expect(list.single.concept, 'Versión nueva');
    }
    await dbA.close();
    await dbB.close();
  });

  test('formato del archivo de la nube es comprimido y legible', () {
    final bytes = SyncService.encodeSnapshot('dev', {
      'expenses': [
        {'id': 'x', 'updated_at': '2026-01-01T00:00:00.000Z'},
      ],
    });
    expect(bytes[0], 0x1f); // cabecera gzip
    final back = SyncService.decodeSnapshot(bytes);
    expect(back['expenses']!.single['id'], 'x');
  });
}

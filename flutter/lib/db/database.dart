import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../contract/contract.dart';

part 'database.g.dart';

// One table per contract entity, one column per contract field, the same
// names in Dart (drift writes them snake_case in SQL). A column that may be
// null in the contract is .nullable().

/// Every row: its id and the two timestamps the writer sets.
mixin RowColumns on Table {
  TextColumn get id => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The contract's local-only columns: kept on the phone, never sent.
mixin LocalColumns on Table {
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
}

@DataClassName('BuildingRow')
class Buildings extends Table with RowColumns, LocalColumns {
  TextColumn get label => text()();
  TextColumn get comment => text().nullable()();
}

@DataClassName('EntranceRow')
class Entrances extends Table with RowColumns, LocalColumns {
  TextColumn get buildingId => text().references(Buildings, #id)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get street => text()();
  TextColumn get number => text()();
  TextColumn get entranceName => text()();
  BoolColumn get coordsConfirmed => boolean()();
  RealColumn get correctedLat => real().nullable()();
  RealColumn get correctedLng => real().nullable()();
  BoolColumn get addressConfirmed => boolean()();
  IntColumn get stories => integer().nullable()();
  IntColumn get flats => integer().nullable()();
  IntColumn get elevators => integer().nullable()();
  IntColumn get yearBuilt => integer().nullable()();
  BoolColumn get groundFloorCommercial => boolean().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get surveyStatus => textEnum<SurveyStatus>()();
  TextColumn get surveyedBy => text().nullable()();
  TextColumn get surveyedAt => text().nullable()();
}

@DataClassName('PhotoRow')
class Photos extends Table with RowColumns, LocalColumns {
  TextColumn get entranceId => text().references(Entrances, #id)();
  TextColumn get fileName => text()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get takenAt => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get heading => real().nullable()();
  TextColumn get uploadState =>
      textEnum<UploadState>().withDefault(const Constant('pending'))();
  TextColumn get reviewStatus =>
      textEnum<ReviewStatus>().withDefault(const Constant('pending'))();
  TextColumn get reviewNote => text().nullable()();
  TextColumn get reviewedBy => text().nullable()();
  TextColumn get replacesPhotoId => text().nullable()();

  /// Where the file is on this phone (local-only, like syncState).
  TextColumn get localUri => text()();
}

@DriftDatabase(tables: [Buildings, Entrances, Photos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            // One file in the app's own sandbox (field.sqlite); on the web,
            // SQLite compiled to WebAssembly in a worker (the two files in web/).
            driftDatabase(
              name: 'field',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  /// First launch only: copy the office's fixtures into the empty tables.
  /// A contract object and a row share their field names, so JSON carries one
  /// into the other; the local-only columns are added on the way.
  Future<void> seedIfEmpty(List<Building> fromOffice, List<Entrance> entrancesFromOffice) async {
    final n = await entrances.count().getSingle();
    if (n > 0) return;
    const synced = {'syncState': 'synced', 'lastError': null}; // the office has them
    await batch((b) {
      b.insertAll(buildings, [
        for (final x in fromOffice) BuildingRow.fromJson({...x.toJson(), ...synced}),
      ]);
      b.insertAll(entrances, [
        for (final x in entrancesFromOffice) EntranceRow.fromJson({...x.toJson(), ...synced}),
      ]);
    });
  }
}

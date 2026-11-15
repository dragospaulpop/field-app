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

  /// Exercise 1 — local-only: when this phone last opened the entrance.
  TextColumn get openedAt => text().nullable()();
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

/// Step 4: the photo queue's four states. Only the queue worker moves a row.
enum QueueState { pending, uploading, synced, failed }

/// Step 4: one row per photo waiting to reach Storage, and everything the
/// worker must remember across a restart: tries so far, when it may try
/// again, why the last try failed. Local only: the server has no such table.
@DataClassName('QueueRow')
class PhotoQueue extends Table {
  TextColumn get id => text()(); // the photo's id (Photos.id)
  TextColumn get entranceId => text()();
  TextColumn get localUri => text()(); // the file in the app's folder (web: a data: URI)
  TextColumn get remotePath => text()(); // <user id>/<entrance id>/<photo id>.jpg, fixed at queue time
  TextColumn get state => textEnum<QueueState>().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().withDefault(const Constant(0))(); // ms since 1970
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()(); // ms since 1970: the order of the queue

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Buildings, Entrances, Photos, PhotoQueue])
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
  int get schemaVersion => 3; // 2: entrances.openedAt (week 4); 3: photo_queue (week 5)

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(
        onCreate: (m) => m.createAll(), // a new install gets every column at once
        onUpgrade: (m, from, to) async {
          // A phone that has version 1 gets the new column, keeping its rows.
          if (from < 2) await m.addColumn(entrances, entrances.openedAt);
          // A phone on version 2 gets the new, empty table; nothing else moves.
          if (from < 3) await m.createTable(photoQueue);
        },
      );

  /// First launch only: copy the office's buildings into the empty table.
  /// The entrances no longer come from the fixtures: since week 4 they are the
  /// pins the cloud assigns to the signed-in worker (sync.dart). A contract
  /// object and a row share their field names, so JSON carries one into the
  /// other; the local-only columns are added on the way.
  Future<void> seedIfEmpty(List<Building> fromOffice) async {
    final n = await buildings.count().getSingle();
    if (n > 0) return;
    const synced = {'syncState': 'synced', 'lastError': null}; // the office has them
    await batch((b) {
      b.insertAll(buildings, [
        for (final x in fromOffice) BuildingRow.fromJson({...x.toJson(), ...synced}),
      ]);
    });
  }

  /// The pull: the cloud's list of my pins becomes the entrances table. A pin
  /// updates its row only when it is newer (updatedAt) than the row, and never
  /// over an unsent survey (syncState pending or failed): the survey the worker
  /// just sent is newer than the office's pin, so it stays on screen. A synced
  /// row that is no longer in the list was taken away: deleted.
  Future<void> savePins(List<Entrance> pins) => transaction(() async {
        for (final pin in pins) {
          final row = EntranceRow.fromJson({...pin.toJson(), 'syncState': 'synced', 'lastError': null})
              .toCompanion(false)
              .copyWith(openedAt: const Value.absent()); // the phone's own column stays
          await into(entrances).insert(
            row,
            onConflict: DoUpdate(
              (_) => row,
              where: (old) =>
                  old.syncState.equalsValue(SyncState.synced) &
                  old.updatedAt.isSmallerThanValue(pin.updatedAt),
            ),
          );
        }
        await (delete(entrances)
              ..where((e) =>
                  e.syncState.equalsValue(SyncState.synced) &
                  e.id.isNotIn([for (final p in pins) p.id])))
            .go();
      });

  /// The outbox: submitted surveys the cloud has not confirmed yet. A failed
  /// one waits for the worker (Retry, or an edit). A missed building (week 3)
  /// waits too: its building is not in the cloud.
  Future<List<Entrance>> outbox() async {
    final q = select(entrances).join([
      innerJoin(buildings, buildings.id.equalsExp(entrances.buildingId)),
    ])
      ..where(entrances.surveyStatus.equalsValue(SurveyStatus.submitted) &
          entrances.syncState.equalsValue(SyncState.pending) &
          buildings.syncState.equalsValue(SyncState.synced));
    return [for (final r in await q.get()) Entrance.fromJson(r.readTable(entrances).toJson())];
  }

  /// After a push: synced, unless the worker changed the survey meanwhile.
  Future<void> markSent(String id, String updatedAt, String? error) =>
      (update(entrances)..where((e) => e.id.equals(id) & e.updatedAt.equals(updatedAt))).write(
        EntrancesCompanion(
          syncState: Value(error == null ? SyncState.synced : SyncState.failed),
          lastError: Value(error),
        ),
      );

  /// No answer, or an error that may pass: still pending, and why.
  Future<void> markWaiting(String id, String updatedAt, String why) =>
      (update(entrances)..where((e) => e.id.equals(id) & e.updatedAt.equals(updatedAt)))
          .write(EntrancesCompanion(lastError: Value(why)));

  /// The server kept a newer version: it replaces the worker's on the phone,
  /// with a sentence that says so. The phone's own openedAt stays.
  Future<void> takeServerVersion(Entrance pin, String note) => into(entrances).insertOnConflictUpdate(
        EntranceRow.fromJson({...pin.toJson(), 'syncState': 'synced', 'lastError': note})
            .toCompanion(false)
            .copyWith(openedAt: const Value.absent()),
      );

  /// Retry: a failed survey goes back to the outbox.
  Future<void> retrySurvey(String id) =>
      (update(entrances)..where((e) => e.id.equals(id) & e.syncState.equalsValue(SyncState.failed)))
          .write(const EntrancesCompanion(syncState: Value(SyncState.pending), lastError: Value(null)));

  /// One entrance's sync state, for its chip.
  Stream<({SyncState state, String? lastError})?> watchSync(String id) =>
      (select(entrances)..where((e) => e.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : (state: r.syncState, lastError: r.lastError));

  /// Dev only (the rules card): a survey the form would never let through.
  Future<void> forceInvalidSurvey(String id) {
    final now = DateTime.now().toUtc().toIso8601String();
    return (update(entrances)..where((e) => e.id.equals(id))).write(EntrancesCompanion(
      stories: const Value(99), // the database allows 1..60
      surveyStatus: const Value(SurveyStatus.submitted),
      updatedAt: Value(now),
      surveyedAt: Value(now),
      syncState: const Value(SyncState.pending),
      lastError: const Value(null),
    ));
  }

  /// What became of a photo's upload (the contract's uploadState; the queue says how).
  Future<void> markPhoto(String id, {String? remoteUrl, String? error}) =>
      (update(photos)..where((p) => p.id.equals(id))).write(PhotosCompanion(
        uploadState: Value(error == null ? UploadState.uploaded : UploadState.failed),
        remoteUrl: Value(remoteUrl),
        lastError: Value(error),
      ));

  // ---- Step 4: the photo queue ----

  /// The next batch: pending rows whose wait is over, oldest first.
  Future<List<QueueRow>> nextBatch(int nowMs, int size) => (select(photoQueue)
        ..where((q) => q.state.equalsValue(QueueState.pending) & q.nextAttemptAt.isSmallerOrEqualValue(nowMs))
        ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
        ..limit(size))
      .get();

  Future<void> setQueue(String id, QueueState state,
          {int? attempts, int? nextAttemptAt, Value<String?> lastError = const Value.absent()}) =>
      (update(photoQueue)..where((q) => q.id.equals(id))).write(PhotoQueueCompanion(
        state: Value(state),
        attempts: Value.absentIfNull(attempts),
        nextAttemptAt: Value.absentIfNull(nextAttemptAt),
        lastError: lastError,
      ));

  /// When the earliest pending row may be tried again (null: none waits).
  Future<int?> nextAttemptAt() {
    final next = photoQueue.nextAttemptAt.min();
    return (selectOnly(photoQueue)
          ..addColumns([next])
          ..where(photoQueue.state.equalsValue(QueueState.pending)))
        .map((r) => r.read(next))
        .getSingle();
  }

  /// At start: a row left 'uploading' was cut off when the app died. The path
  /// is fixed and the upload overwrites, so sending it again is harmless.
  Future<int> resumeUploading() => (update(photoQueue)..where((q) => q.state.equalsValue(QueueState.uploading)))
      .write(const PhotoQueueCompanion(state: Value(QueueState.pending)));

  /// Retry: a failed photo starts over, with its tries reset.
  Future<void> retryPhotos() => (update(photoQueue)..where((q) => q.state.equalsValue(QueueState.failed))).write(
      const PhotoQueueCompanion(state: Value(QueueState.pending), attempts: Value(0), nextAttemptAt: Value(0)));

  /// The banner's photo line: how many rows are in each state, and the last problem.
  Stream<({Map<QueueState, int> counts, String? lastError})> watchQueue() =>
      select(photoQueue).watch().map((rows) => (
            counts: {for (final s in QueueState.values) s: rows.where((r) => r.state == s).length},
            lastError: rows.where((r) => r.state != QueueState.synced).map((r) => r.lastError).nonNulls.firstOrNull,
          ));

  Future<PhotoRow> photo(String id) => (select(photos)..where((p) => p.id.equals(id))).getSingle();

  /// The banner's count: what still waits to be sent, and the last refusal.
  Stream<({int pending, int failed, String? lastError})> watchOutbox() =>
      (select(entrances)
            ..where((e) => e.syncState.isInValues([SyncState.pending, SyncState.failed])))
          .watch()
          .map((rows) => (
                pending: rows.where((r) => r.syncState == SyncState.pending).length,
                failed: rows.where((r) => r.syncState == SyncState.failed).length,
                lastError: rows.map((r) => r.lastError).nonNulls.firstOrNull,
              ));

  // ---- Reads: streams that emit again whenever a table they read changes ----

  Stream<List<Entrance>> watchEntrances() => select(entrances)
      .watch()
      .map((rows) => [for (final r in rows) Entrance.fromJson(r.toJson())]);

  Stream<Entrance?> watchEntrance(String id) =>
      (select(entrances)..where((e) => e.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : Entrance.fromJson(r.toJson()));

  Stream<Building?> watchBuilding(String id) =>
      (select(buildings)..where((b) => b.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : Building.fromJson(r.toJson()));

  Stream<List<PhotoRow>> watchPhotos(String entranceId) =>
      (select(photos)..where((p) => p.entranceId.equals(entranceId))).watch();

  /// Exercise 1: the new column, read like any other.
  Stream<String?> watchOpenedAt(String id) =>
      (select(entrances)..where((e) => e.id.equals(id))).watchSingleOrNull().map((r) => r?.openedAt);

  // ---- Writes ----

  Future<void> markOpened(String id) =>
      (update(entrances)..where((e) => e.id.equals(id))).write(
        EntrancesCompanion(openedAt: Value(DateTime.now().toUtc().toIso8601String())),
      );

  /// A building the office missed: the worker stands at its door and makes
  /// both rows on the phone, with ids born here (UUID v4). The office learns of
  /// it at the first sync (week 4); until then it is 'pending', like any new row.
  Future<String> addMissedEntrance(double lat, double lng, String buildingId, String entranceId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await into(buildings).insert(BuildingsCompanion.insert(
        id: buildingId,
        createdAt: now,
        updatedAt: now,
        label: 'New building',
        comment: const Value('Added in the field: not on the office map.'),
      ));
      await into(entrances).insert(EntrancesCompanion.insert(
        id: entranceId,
        createdAt: now,
        updatedAt: now,
        buildingId: buildingId,
        lat: lat,
        lng: lng,
        street: '?', // the survey asks for the real address
        number: '?',
        entranceName: 'Sc. 1',
        coordsConfirmed: true, // the pin is where the worker stands: at the door
        addressConfirmed: false,
        surveyStatus: SurveyStatus.in_progress,
      ));
    });
    return entranceId;
  }

  /// The survey goes to SQLite: it survives a restart and waits for week 4's push.
  Future<void> submitSurvey(Entrance surveyed, String me) {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = surveyed.copyWith(
      surveyStatus: SurveyStatus.submitted,
      surveyedBy: me,
      surveyedAt: now,
      updatedAt: now,
    );
    return into(entrances).insertOnConflictUpdate(EntranceRow.fromJson({
      ...row.toJson(),
      'syncState': 'pending', // the office has not seen this version yet
      'lastError': null,
    }));
  }
}

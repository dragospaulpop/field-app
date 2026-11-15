import 'dart:async';
import 'dart:io' show File;
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, InsertMode, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contract/contract.dart' show UploadState;
import 'db/database.dart';
import 'providers.dart';
import 'session.dart';
import 'supabase_repositories.dart';

const batchSize = 3; // photos in flight at once
const baseMs = 2000; // the first retry waits up to 2 s…
const capMs = 300000; // …and no wait is ever longer than 5 minutes
const maxAttempts = 6; // then the row is failed and waits for Retry

/// Full jitter: a random wait between 0 and min(cap, base × 2^attempt).
/// Backoff spreads one phone's retries over time; jitter spreads the phones.
/// The dice are a parameter so a test can pass its own.
int retryDelay(int attempt, [Random? rng]) {
  final ceiling = min(capMs, baseMs * pow(2, attempt).toInt());
  return ((rng ?? Random()).nextDouble() * ceiling).round();
}

/// The worker's switch: may photos use mobile data? Off by default (a
/// student's plan, a worker's roaming), kept in the preferences like the
/// last tab, so it survives a restart.
class CellularNotifier extends Notifier<bool> {
  @override
  bool build() {
    photosOnMobileData().then((on) => state = on);
    return false;
  }

  void set(bool allowed) {
    state = allowed;
    savePhotosOnMobileData(allowed);
  }
}

final allowCellularProvider = NotifierProvider<CellularNotifier, bool>(CellularNotifier.new);

/// The policy: on Wi-Fi or Ethernet, yes; on mobile data only if allowed.
/// connectivity_plus tells the TYPE of the link, never its quality or whether
/// the internet answers (a captive portal is "wifi" too): a filter, not a
/// promise. The upload itself is the test. On the web it says "wifi" whenever
/// the browser is online.
Future<bool> mayUpload({required bool allowCellular}) async {
  // A list: a phone can be on several networks at once.
  final links = await Connectivity().checkConnectivity();
  if (links.contains(ConnectivityResult.wifi) || links.contains(ConnectivityResult.ethernet)) return true;
  return allowCellular && links.contains(ConnectivityResult.mobile);
}

/// PNG files start with these four bytes; anything else is sent as JPEG (the
/// camera and the picker give JPEG). Storage checks the type the app
/// declares, not the bytes: the app must declare the right one.
bool _isPng(Uint8List b) => b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

/// Queue a photo the moment it is saved: its path in Storage is fixed now, so
/// a retry writes the same object again instead of a second copy. A photo
/// already queued is left as it is.
Future<void> enqueuePhoto(AppDatabase db, PhotoRow p, String uid) async {
  final ext = _isPng(await _bytes(p.localUri)) ? 'png' : 'jpg';
  await db.into(db.photoQueue).insert(
        PhotoQueueCompanion.insert(
          id: p.id,
          entranceId: p.entranceId,
          localUri: p.localUri,
          remotePath: '$uid/${p.entranceId}/${p.id}.$ext',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

/// At start: photos taken before the queue existed (weeks 3 and 4) join it.
Future<void> enqueueLeftovers(AppDatabase db, String uid) async {
  final waiting = await (db.select(db.photos)..where((p) => p.uploadState.equalsValue(UploadState.uploaded).not())).get();
  for (final p in waiting) {
    await enqueuePhoto(db, p, uid);
  }
}

/// The queue's worker. A Provider's Ref lives as long as the app, unlike a
/// screen's WidgetRef: the wake-up timer may fire after that screen is gone.
final photoQueueProvider = Provider((ref) {
  final q = PhotoQueue(ref);
  ref.onDispose(q.stop);
  return q;
});

class PhotoQueue {
  PhotoQueue(this._ref);

  final Ref _ref;
  var _running = false;
  Timer? _wake;

  /// Stop the wake-up timer (sign-out). The queue itself stays in SQLite.
  void stop() => _wake?.cancel();

  /// Single-flight, a batch at a time while the policy allows, re-reading the
  /// table after every batch. Triggers: app start, back in the foreground, the
  /// network back, a new photo, Retry, Sync now (sync.dart, photos.dart).
  /// Foreground only: when the app is killed the queue waits in SQLite.
  Future<void> drain() async {
    if (_running) return;
    _running = true;
    final db = _ref.read(databaseProvider);
    var allowed = false;
    try {
      while (allowed = await mayUpload(allowCellular: _ref.read(allowCellularProvider))) {
        final batch = await db.nextBatch(DateTime.now().millisecondsSinceEpoch, batchSize);
        if (batch.isEmpty) break;
        await Future.wait(batch.map((row) => _uploadOne(db, row)));
      }
    } finally {
      _running = false;
    }
    // The schedule is in the table, not in a sleeping loop: wake up when the
    // earliest waiting row may be tried again. Not allowed now (offline, or
    // mobile data off): the network's next change wakes the queue instead.
    final next = allowed ? await db.nextAttemptAt() : null;
    _wake?.cancel();
    if (next != null) {
      _wake = Timer(Duration(milliseconds: max(0, next - DateTime.now().millisecondsSinceEpoch)), drain);
    }
  }
}

/// The bytes of a kept photo: a file on Android and iOS, a data: URI on the web.
Future<Uint8List> _bytes(String localUri) async => localUri.startsWith('data:')
    ? UriData.parse(localUri).contentAsBytes()
    : await File(localUri).readAsBytes();

/// One photo: the file first, then its row. Never throws: every outcome is
/// written into its queue row. A photo cut off halfway starts again from byte 0.
Future<void> _uploadOne(AppDatabase db, QueueRow row) async {
  await db.setQueue(row.id, QueueState.uploading);
  try {
    // uploadBinary works on every platform (upload(File) needs dart:io: not
    // on the web). upsert: a retry may meet the file it already sent.
    final type = row.remotePath.endsWith('.png') ? 'image/png' : 'image/jpeg';
    await supabase.storage.from('survey-photos').uploadBinary(
          row.remotePath,
          await _bytes(row.localUri),
          fileOptions: FileOptions(contentType: type, upsert: true),
        );
    // The row exists only for a finished upload: workers may insert a
    // survey_photos row, never update one. A retry that finds it there is done.
    final p = await db.photo(row.id);
    try {
      await supabase.from('survey_photos').insert({
        'id': p.id,
        'entrance_id': p.entranceId,
        'file_name': row.remotePath.split('/').last,
        'remote_path': row.remotePath,
        'taken_at': p.takenAt,
        'lat': p.lat,
        'lng': p.lng,
        'heading': p.heading,
        'upload_state': 'uploaded',
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505: this photo's row is there already
    }
    await db.setQueue(row.id, QueueState.synced, lastError: const Value(null));
    await db.markPhoto(row.id);
  } catch (e) {
    final attempts = row.attempts + 1;
    final why = switch (e) {
      StorageException(:final statusCode, :final message) => 'Storage $statusCode: $message',
      PostgrestException(:final code, :final message) => '$code: $message',
      _ => '$e',
    };
    // Waiting will not help: a 4xx from Storage (too large, wrong type, not
    // allowed), except 408 (timeout) and 429 (too many requests), and a
    // refused row (42501). Failed at once, for the worker to see.
    final permanent = switch (e) {
      StorageException(:final statusCode?) =>
        statusCode.startsWith('4') && statusCode != '408' && statusCode != '429',
      PostgrestException(:final code) => code == '42501',
      _ => false,
    };
    if (permanent || attempts >= maxAttempts) {
      await db.setQueue(row.id, QueueState.failed, attempts: attempts, lastError: Value(why));
      await db.markPhoto(row.id, error: why);
    } else {
      await db.setQueue(row.id, QueueState.pending,
          attempts: attempts,
          nextAttemptAt: DateTime.now().millisecondsSinceEpoch + retryDelay(row.attempts),
          lastError: Value(why));
    }
  }
}

final queueProvider = StreamProvider((ref) => ref.watch(databaseProvider).watchQueue());

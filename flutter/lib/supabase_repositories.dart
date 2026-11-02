import 'package:supabase_flutter/supabase_flutter.dart';

import 'contract/contract.dart';
import 'repositories.dart';

final supabase = Supabase.instance.client;

/// PostgREST answers `2026-11-03T16:30:00.123456+00:00`; the contract (and
/// SQLite's string comparisons) want the `Z` form. Converted here, once.
String? _z(String? t) => t == null ? null : DateTime.parse(t).toUtc().toIso8601String();

/// Postgres speaks snake_case, the contract camelCase. This is the ONLY place
/// that knows both: a row in, a contract Entrance out.
Entrance entranceFromRow(Map<String, dynamic> r) => Entrance.fromJson({
      'id': r['id'],
      'createdAt': _z(r['created_at']),
      'updatedAt': _z(r['updated_at']),
      'buildingId': r['building_id'],
      'lat': r['lat'],
      'lng': r['lng'],
      'street': r['street'],
      'number': r['number'],
      'entranceName': r['entrance_name'],
      'coordsConfirmed': r['coords_confirmed'],
      'correctedLat': r['corrected_lat'],
      'correctedLng': r['corrected_lng'],
      'addressConfirmed': r['address_confirmed'],
      'stories': r['stories'],
      'flats': r['flats'],
      'elevators': r['elevators'],
      'yearBuilt': r['year_built'],
      'groundFloorCommercial': r['ground_floor_commercial'],
      'comment': r['comment'],
      'surveyStatus': r['survey_status'],
      'surveyedBy': r['surveyed_by'],
      'surveyedAt': _z(r['surveyed_at']),
    });

/// The survey's columns, snake_case, from a survey as it travels (surveyDoc).
/// Only the worker's columns: never lat, lng, building_id or assigned_to.
Map<String, Object?> surveyColumns(Map<String, Object?> s) => {
      'street': s['street'],
      'number': s['number'],
      'entrance_name': s['entranceName'],
      'coords_confirmed': s['coordsConfirmed'],
      'corrected_lat': s['correctedLat'],
      'corrected_lng': s['correctedLng'],
      'address_confirmed': s['addressConfirmed'],
      'stories': s['stories'],
      'flats': s['flats'],
      'elevators': s['elevators'],
      'year_built': s['yearBuilt'],
      'ground_floor_commercial': s['groundFloorCommercial'],
      'comment': s['comment'],
      'survey_status': s['surveyStatus'],
      'surveyed_by': s['surveyedBy'],
      'surveyed_at': s['surveyedAt'],
    };

class SupabasePinsRepository implements PinsRepository {
  /// One fetch of my pins. Firestore pushed every change; a plain query does
  /// not, so the app asks again on start, back in the foreground and on
  /// "Sync now" (sync.dart). Realtime, which pushes, is the stretch moon.
  @override
  Stream<List<Entrance>> watchMine(String uid) async* {
    // RLS already limits this to my rows; the filter states the intent and uses the index.
    final rows = await supabase.from('entrances').select().eq('assigned_to', uid);
    yield [for (final r in rows) entranceFromRow(r)];
  }

  /// The office assigns pins (step 1's SQL): a worker has no insert grant.
  @override
  Future<({int created, int refused})> seed(String uid, List<Entrance> pins) async =>
      (created: 0, refused: 0);
}

class SupabaseSurveysRepository implements SurveysRepository {
  @override
  Future<void> push(Map<String, Object?> survey) async {
    // An update of the row the office made, by the entrance's UUID: sending the
    // same survey twice writes the same values twice (idempotent).
    final changed = await supabase
        .from('entrances')
        .update({...surveyColumns(survey), 'updated_at': survey['updatedAt']})
        .eq('id', survey['id']!)
        .select('id'); // ask for the changed rows back
    // Zero rows and no error: RLS hid the row (it is not mine any more). A refusal.
    if (changed.isEmpty) {
      throw const PostgrestException(
          message: 'refused: this entrance is no longer assigned to you', code: 'not-mine');
    }
  }
}

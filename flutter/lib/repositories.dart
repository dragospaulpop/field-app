import 'contract/contract.dart';

// What the app needs from "the cloud", and nothing about how. Screens and the
// sync code use these interfaces; only supabase_repositories.dart knows
// Supabase. Week 5 swapped week 4's Firebase implementation for it.

abstract class PinsRepository {
  /// All my pins now (and again each time the stream is asked for anew).
  Stream<List<Entrance>> watchMine(String uid);

  /// Dev only: make these pins mine. Counts the ones that already belong to someone.
  Future<({int created, int refused})> seed(String uid, List<Entrance> pins);
}

abstract class SurveysRepository {
  /// Idempotent: sending the same survey twice leaves one row as it was.
  Future<void> push(Map<String, Object?> survey);
}

/// The surveyed fields of an entrance (the contract's survey form).
const surveyFields = [
  'coordsConfirmed', 'correctedLat', 'correctedLng', 'street', 'number',
  'entranceName', 'comment', 'addressConfirmed', 'stories', 'flats',
  'elevators', 'yearBuilt', 'groundFloorCommercial',
];

/// A survey as it travels: the surveyed fields, who, when, and which entrance.
/// Its id is the entrance's UUID: one survey per entrance, so a resend overwrites.
Map<String, Object?> surveyDoc(Entrance e, String uid) {
  final j = e.toJson();
  return {
    for (final k in surveyFields) k: j[k],
    'id': e.id,
    'surveyStatus': e.surveyStatus.name,
    'surveyedBy': uid,
    'surveyedAt': e.surveyedAt ?? e.updatedAt,
    'updatedAt': e.updatedAt,
  };
}

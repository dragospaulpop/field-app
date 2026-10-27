import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'contract/contract.dart';
import 'repositories.dart';

class FirebasePinsRepository implements PinsRepository {
  final _pins = FirebaseFirestore.instance.collection('pins');

  @override
  Stream<List<Entrance>> watchMine(String uid) => _pins
      // The query asks for exactly what the rules allow: my pins, and only mine.
      .where('assignedTo', isEqualTo: uid)
      .snapshots()
      .map((snap) => [
            for (final d in snap.docs) Entrance.fromJson(d.data()..remove('assignedTo')),
          ]);

  @override
  Future<({int created, int refused})> seed(String uid, List<Entrance> pins) async {
    // One write per pin: a pin someone else already has is refused by the
    // rules (it would be an update), and the others still go through.
    var created = 0;
    await Future.wait([
      for (final p in pins)
        _pins
            .doc(p.id)
            .set({...p.toJson(), 'assignedTo': uid})
            .then((_) => created++, onError: (Object _) {}),
    ]);
    return (created: created, refused: pins.length - created);
  }
}

class FirebaseSurveysRepository implements SurveysRepository {
  @override
  Future<void> push(Map<String, Object?> survey) =>
      // The document id is the survey's UUID: a second push overwrites it.
      FirebaseFirestore.instance.collection('surveys').doc(survey['id']! as String).set(survey);

  @override
  Stream<Map<String, dynamic>?> watchLastSent(String uid) => FirebaseFirestore.instance
      .collection('surveys')
      // where on one field + orderBy on another: Firestore needs a composite index.
      .where('surveyedBy', isEqualTo: uid)
      .orderBy('surveyedAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.data());

  @override
  Stream<CloudSurvey> watchOne(String id) => FirebaseFirestore.instance
      .collection('surveys')
      .doc(id)
      .snapshots()
      .map<CloudSurvey>((snap) => snap.exists
          ? (state: CloudState.sent, updatedAt: snap.data()!['updatedAt'] as String?)
          : (state: CloudState.none, updatedAt: null))
      // permission-denied: the rules said no
      .transform(StreamTransformer.fromHandlers(
        handleError: (Object e, StackTrace s, EventSink<CloudSurvey> sink) =>
            sink.add((state: CloudState.denied, updatedAt: null)),
      ));
}

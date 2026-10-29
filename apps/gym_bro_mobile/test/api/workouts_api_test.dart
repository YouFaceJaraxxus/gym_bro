import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/exercise.dart';
import 'package:gym_bro_mobile/models/routine.dart';
import 'package:gym_bro_mobile/models/training.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:gym_bro_mobile/services/offline/offline_support.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Bodies captured from the local stack (GET /exercises/:id, /trainings/:id,
// /routines/:id, /training-sessions/:id), trimmed.
const elenaId = 'f591534f-a631-4b71-9fd4-b8260e6f3ee6';
const liamId = '8d0b05de-7c18-441b-9536-aaa042eaeaaa';
const exerciseId = '957387c0-314e-4eb4-9a8a-80f0b1e8275c';
const trainingId = '03c14d39-ae9f-425f-b7ee-3dcdbb3cc0c2';
const routineId = 'b6bf31da-11ad-4807-aa78-51f8ee082c34';
const sessionId = '5516dfed-3ffc-4f62-ab82-d9749b5307f8';

/// Exactly what the API sends: Postgres `muscle_group[]` columns come through
/// as array literals, not JSON arrays.
final exerciseJson = {
  'id': exerciseId,
  'name': 'Arnold Press',
  'description': 'A seated dumbbell press that rotates the palms from facing you to facing forward on the way up.',
  'note': 'Rotate smoothly as you press; finish with the palms facing forward.',
  'image_url': '/storage/v1/object/public/media/exercises/illustrations/arnold-press.jpg?v=69d12a51',
  'video_url': null,
  'author_id': elenaId,
  'primary_muscles': '{delts_front,delts_medial}',
  'secondary_muscles': '{triceps_all}',
  'is_public': true,
  'created_at': '2026-10-28T10:58:39.845Z',
  'updated_at': '2026-10-28T10:58:39.845Z',
};

/// The same exercise with JSON-array muscles (the shape Exercise.fromJson
/// expects, and what the POST/PUT bodies use).
final exerciseJsonArrays = {
  ...exerciseJson,
  'primary_muscles': ['delts_front', 'delts_medial'],
  'secondary_muscles': ['triceps_all'],
};

final trainingListJson = {
  'id': trainingId,
  'name': 'Core & Lower Body Finisher',
  'description': 'A shorter accessory session pairing glute and hamstring work with a core-focused circuit.',
  'notes': null,
  'author_id': elenaId,
  'is_public': true,
  'created_at': '2026-09-15T16:06:25.090Z',
  'updated_at': '2026-09-15T16:06:25.090Z',
  'thumbnail': {
    'id': '523c59a8-2da7-4f27-9f48-2dc723729ce9',
    'training_id': trainingId,
    'url': 'https://picsum.photos/seed/training-Core%20%26%20Lower%20Body%20Finisher/800/450',
    'is_thumbnail': true,
    'position': 0,
  },
};

final trainingDetailJson = {
  ...Map.of(trainingListJson)..remove('thumbnail'),
  'images': [
    {
      'id': '523c59a8-2da7-4f27-9f48-2dc723729ce9',
      'training_id': trainingId,
      'url': 'https://picsum.photos/seed/training-Core%20%26%20Lower%20Body%20Finisher/800/450',
      'is_thumbnail': true,
      'position': 0,
    },
  ],
  'sets': [
    {
      'id': 'e96ddbd8-7fa8-4606-8b43-01d20a2cd6bf',
      'training_id': trainingId,
      'type': 'standard',
      'position': 1,
      'rest_seconds': 90,
      'note': null,
      'exercises': [
        {
          'id': 'd92f1885-fe39-4fbc-9f9b-86f2ccfada7a',
          'training_set_id': 'e96ddbd8-7fa8-4606-8b43-01d20a2cd6bf',
          'exercise_id': '37be9536-1e89-4d41-93c8-22e71c6b87e9',
          'position': 0,
          'is_alternating': false,
          'rest_between_drops_seconds': null,
          'note': null,
          'drops': [
            {
              'id': 'e2de842a-a193-4cb0-ba65-4d5310be8d8a',
              'training_set_exercise_id': 'd92f1885-fe39-4fbc-9f9b-86f2ccfada7a',
              'drop_number': 0,
              'rep_type': 'count',
              'rep_count': 10,
              'weight_kg': null,
              'side': 'both',
              'note': null,
            },
            {
              'id': '8722c574-3109-4953-9dfb-5e283d1b7b67',
              'training_set_exercise_id': 'd92f1885-fe39-4fbc-9f9b-86f2ccfada7a',
              'drop_number': 1,
              'rep_type': 'failure',
              'rep_count': null,
              // numeric(6,2) → JSON string
              'weight_kg': '62.50',
              'side': 'left',
              'note': 'Slow eccentric',
            },
          ],
        },
      ],
    },
    {
      'id': 'dfefbcc9-b1c2-4a6d-9734-87ea26dfe7ab',
      'training_id': trainingId,
      'type': 'circuit',
      'position': 4,
      'rest_seconds': 30,
      'note': 'No rest between moves',
      'exercises': [
        {
          'id': '377d89e6-b6bc-4803-8cdd-cbd9d1524822',
          'training_set_id': 'dfefbcc9-b1c2-4a6d-9734-87ea26dfe7ab',
          'exercise_id': '75c393d8-0c5d-465a-b94c-66842ecb35e8',
          'position': 0,
          'is_alternating': true,
          'rest_between_drops_seconds': 15,
          'note': null,
          'drops': [],
        },
      ],
    },
  ],
};

final routineListJson = {
  'id': routineId,
  'name': 'Full Body 3x/Week',
  'description': 'A beginner-friendly full-body routine trained three non-consecutive days a week.',
  'notes': null,
  'author_id': elenaId,
  'is_public': true,
  'schedule_type': 'fixed_weeks',
  'num_weeks': 4,
  'created_at': '2026-09-15T16:06:25.116Z',
  'updated_at': '2026-09-15T16:06:25.116Z',
  'thumbnail': {
    'id': '7d21f02c-6c1d-4609-8c8b-7b6701cd0db9',
    'routine_id': routineId,
    'url': 'https://picsum.photos/seed/routine-Full%20Body%203x%2FWeek/800/450',
    'is_thumbnail': true,
    'position': 0,
  },
};

/// GET /routines/:id. Each entry embeds a *summary* of its training
/// (id, name, description, is_public — no timestamps, no sets).
final routineDetailJson = {
  ...Map.of(routineListJson)..remove('thumbnail'),
  'images': [
    {
      'id': '7d21f02c-6c1d-4609-8c8b-7b6701cd0db9',
      'routine_id': routineId,
      'url': 'https://picsum.photos/seed/routine-Full%20Body%203x%2FWeek/800/450',
      'is_thumbnail': true,
      'position': 0,
    },
  ],
  'trainings': [
    {
      'id': '03148572-6cc0-4525-8bf7-b5c9d180bb26',
      'routine_id': routineId,
      'training_id': '9318e8ac-468a-4f9f-a08f-815f56c33f1b',
      'week_number': 1,
      'day_of_week': 1,
      'position': 0,
      'note': null,
      'training': {
        'id': '9318e8ac-468a-4f9f-a08f-815f56c33f1b',
        'name': 'Full Body Beginner',
        'description': 'An introductory full-body routine covering one major push, pull, and lower-body lift.',
        'is_public': true,
      },
    },
  ],
};

final sessionListJson = {
  'id': sessionId,
  'user_id': liamId,
  'trainer_id': null,
  'training_id': '5391ad95-91d3-42bc-96f1-22af7f156617',
  'started_at': '2026-10-26T19:05:00.000Z',
  'ended_at': '2026-10-26T20:37:00.000Z',
  'notes': null,
  'created_at': '2026-10-27T18:25:54.604Z',
  'updated_at': '2026-10-27T18:25:54.604Z',
  'comment_count': 0,
  'trainer_name': null,
};

Map<String, dynamic> dropLog(String id, int n, int reps, String? weight) => {
      'id': id,
      'session_set_log_id': '55ef1b3b-eb4d-43b9-a51e-a9d018ccb3d7',
      'training_set_drop_id': '89ad6315-50cf-47db-9062-da191477c638',
      'drop_number': n,
      'rep_type_actual': 'count',
      'rep_count_actual': reps,
      'weight_kg_actual': weight,
      'side': 'both',
      'note': null,
    };

final setLogJson = {
  'id': '55ef1b3b-eb4d-43b9-a51e-a9d018ccb3d7',
  'session_id': sessionId,
  'training_set_id': '3b8f5eac-eca3-45bb-9348-6a315f6f2cb2',
  'exercise_id': null,
  'position': 0,
  'note': null,
  'drop_logs': [
    dropLog('61447e64-e58d-4b45-b9be-8af5ece69fbb', 0, 8, '105.00'),
    dropLog('d5814cb3-8d85-43f7-8528-d5842c8b4772', 1, 7, '108.75'),
  ],
};

final sessionDetailJson = {
  ...sessionListJson,
  'trainer_id': elenaId,
  'trainer_name': 'Elena Vasquez',
  'notes': 'Felt strong',
  'comment_count': '3',
  'set_logs': [setLogJson],
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('exercises', () {
    test('getExercises sends paging defaults only', () async {
      backend().on('GET /exercises', ok([exerciseJsonArrays]));
      final list = await ctx.api().getExercises(token);
      expectGet(backend().only, '/exercises', {'page': '0', 'page_size': '20'});
      expect(list.single.id, exerciseId);
    });

    test('getExercises sends every filter, encoded', () async {
      backend().on('GET /exercises', ok([]));
      await ctx.api().getExercises(
        token,
        name: 'bench & press',
        muscle: MuscleGroup.chestUpper,
        authorId: elenaId,
        isPublic: false,
        page: 3,
        pageSize: 50,
      );
      final r = backend().only;
      expectGet(r, '/exercises', {
        'page': '3',
        'page_size': '50',
        'name': 'bench & press',
        'muscle': 'chest_upper',
        'author_id': elenaId,
        'is_public': 'false',
      });
      expect(r.url.query, contains('name=bench%20%26%20press'));
    });

    test('getExercise parses every field (JSON-array muscles)', () async {
      backend().on('GET /exercises/$exerciseId', ok(exerciseJsonArrays));
      final e = await ctx.api().getExercise(token, exerciseId);
      expectGet(backend().only, '/exercises/$exerciseId');
      expect(e.id, exerciseId);
      expect(e.name, 'Arnold Press');
      expect(e.description, startsWith('A seated dumbbell press'));
      expect(e.note, startsWith('Rotate smoothly'));
      expect(e.imageUrl, '/storage/v1/object/public/media/exercises/illustrations/arnold-press.jpg?v=69d12a51');
      expect(e.displayImageUrl, '${AppConfig.supabaseOrigin}${e.imageUrl}');
      expect(e.videoUrl, isNull);
      expect(e.authorId, elenaId);
      expect(e.primaryMuscles, [MuscleGroup.deltsFront, MuscleGroup.deltsMedial]);
      expect(e.secondaryMuscles, [MuscleGroup.tricepsAll]);
      expect(e.isPublic, isTrue);
      expect(e.createdAt, DateTime.utc(2026, 10, 28, 10, 58, 39, 845));
      expect(e.updatedAt, DateTime.utc(2026, 10, 28, 10, 58, 39, 845));
    });

    test('getExercise parses the real payload (everything but muscles)', () async {
      backend().on('GET /exercises/$exerciseId', ok(exerciseJson));
      final e = await ctx.api().getExercise(token, exerciseId);
      expect(e.name, 'Arnold Press');
      expect(e.authorId, elenaId);
      expect(e.isPublic, isTrue);
    });

    // Older API versions sent primary_muscles / secondary_muscles as Postgres
    // array literals ("{delts_front,delts_medial}"); cached responses may
    // still have them.
    test('getExercises parses muscles sent as a Postgres array literal', () async {
      backend().on('GET /exercises', ok([exerciseJson]));
      final e = (await ctx.api().getExercises(token)).single;
      expect(e.primaryMuscles, [MuscleGroup.deltsFront, MuscleGroup.deltsMedial]);
      expect(e.secondaryMuscles, [MuscleGroup.tricepsAll]);
    });

    test('createExercise POSTs the form data', () async {
      final data = {
        'name': 'Arnold Press',
        'description': null,
        'note': 'Rotate smoothly',
        'image_url': null,
        'video_url': 'https://youtu.be/abc',
        'primary_muscles': ['delts_front', 'delts_medial'],
        'secondary_muscles': <String>[],
        'is_public': false,
      };
      backend().on('POST /exercises', ok({...exerciseJsonArrays, 'is_public': false}, 201));
      final e = await ctx.api().createExercise(token, data);
      expectJson(backend().only, 'POST', '/exercises', data);
      expect(e.isPublic, isFalse);
    });

    test('updateExercise PUTs /exercises/:id', () async {
      backend().on('PUT /exercises/$exerciseId', ok({...exerciseJsonArrays, 'name': 'Arnold Press (seated)'}));
      final e = await ctx.api().updateExercise(token, exerciseId, {'name': 'Arnold Press (seated)'});
      expectJson(backend().only, 'PUT', '/exercises/$exerciseId', {'name': 'Arnold Press (seated)'});
      expect(e.name, 'Arnold Press (seated)');
    });

    test('deleteExercise DELETEs; a 409 (used by a training) surfaces', () async {
      backend().on('DELETE /exercises/$exerciseId', ok('', 204));
      await ctx.api().deleteExercise(token, exerciseId);
      expectDelete(backend().only, '/exercises/$exerciseId');

      backend().on('DELETE /exercises/$exerciseId', err(409, "Exercise is used by a training and can't be deleted"));
      await expectLater(
        ctx.api().deleteExercise(token, exerciseId),
        throwsApiError("Exercise is used by a training and can't be deleted"),
      );
    });
  });

  group('trainings', () {
    test('getTrainings: defaults, then name/author/mine filters', () async {
      backend().on('GET /trainings', ok([trainingListJson]));
      final list = await ctx.api().getTrainings(token);
      expectGet(backend().requests.last, '/trainings', {'page': '0', 'page_size': '20'});
      final t = list.single;
      expect(t.name, 'Core & Lower Body Finisher');
      expect(t.notes, isNull);
      expect(t.images, isEmpty);
      expect(t.sets, isEmpty);
      expect(t.thumbnail!.id, '523c59a8-2da7-4f27-9f48-2dc723729ce9');
      expect(t.thumbnail!.isThumbnail, isTrue);
      expect(t.thumbnailUrl, contains('training-Core%20%26%20Lower'));

      await ctx.api().getTrainings(token, name: 'full body', authorId: elenaId, mine: true, page: 1, pageSize: 10);
      expectGet(backend().requests.last, '/trainings', {
        'page': '1',
        'page_size': '10',
        'name': 'full body',
        'author_id': elenaId,
        'mine': 'true',
      });
    });

    test('getTraining parses sets, exercises and drops (numeric strings)', () async {
      backend().on('GET /trainings/$trainingId', ok(trainingDetailJson));
      final t = await ctx.api().getTraining(token, trainingId);
      expectGet(backend().only, '/trainings/$trainingId');

      expect(t.id, trainingId);
      expect(t.authorId, elenaId);
      expect(t.isPublic, isTrue);
      expect(t.thumbnail, isNull);
      expect(t.images.single.url, contains('picsum.photos'));
      expect(t.images.single.trainingId, trainingId);
      expect(t.createdAt, DateTime.utc(2026, 9, 15, 16, 6, 25, 90));
      expect(t.sets, hasLength(2));

      final s = t.sets[0];
      expect(s.id, 'e96ddbd8-7fa8-4606-8b43-01d20a2cd6bf');
      expect(s.trainingId, trainingId);
      expect(s.type, WorkoutSetType.standard);
      expect(s.position, 1);
      expect(s.restSeconds, 90);
      expect(s.note, isNull);
      final ex = s.exercises.single;
      expect(ex.exerciseId, '37be9536-1e89-4d41-93c8-22e71c6b87e9');
      expect(ex.exercise, isNull);
      expect(ex.isAlternating, isFalse);
      expect(ex.restBetweenDropsSeconds, isNull);
      expect(ex.drops, hasLength(2));
      final d0 = ex.drops[0], d1 = ex.drops[1];
      expect(d0.dropNumber, 0);
      expect(d0.repType, RepType.count);
      expect(d0.repCount, 10);
      expect(d0.weightKg, isNull);
      expect(d0.side, BodySide.both);
      expect(d1.repType, RepType.failure);
      expect(d1.repCount, isNull);
      expect(d1.weightKg, 62.5);
      expect(d1.side, BodySide.left);
      expect(d1.note, 'Slow eccentric');

      final circuit = t.sets[1];
      expect(circuit.type, WorkoutSetType.circuit);
      expect(circuit.restSeconds, 30);
      expect(circuit.note, 'No rest between moves');
      expect(circuit.exercises.single.isAlternating, isTrue);
      expect(circuit.exercises.single.restBetweenDropsSeconds, 15);
      expect(circuit.exercises.single.drops, isEmpty);
    });

    final trainingBody = {
      'name': 'Core & Lower Body Finisher',
      'description': null,
      'notes': null,
      'is_public': true,
      'images': [
        {'url': 'https://example.com/t.jpg', 'is_thumbnail': true, 'position': 0},
      ],
      'sets': [
        {
          'type': 'superset',
          'position': 0,
          'rest_seconds': 60,
          'note': null,
          'exercises': [
            {
              'exercise_id': exerciseId,
              'position': 0,
              'is_alternating': false,
              'rest_between_drops_seconds': null,
              'note': null,
              'drops': [
                {'drop_number': 0, 'rep_type': 'count', 'rep_count': 8, 'weight_kg': 22.5, 'side': 'both', 'note': null},
              ],
            },
          ],
        },
      ],
    };

    test('createTraining POSTs the nested body', () async {
      backend().on('POST /trainings', ok(trainingDetailJson, 201));
      final t = await ctx.api().createTraining(token, trainingBody);
      expectJson(backend().only, 'POST', '/trainings', trainingBody);
      expect(t.sets, hasLength(2));
    });

    test('updateTraining PUTs /trainings/:id', () async {
      backend().on('PUT /trainings/$trainingId', ok(trainingDetailJson));
      final t = await ctx.api().updateTraining(token, trainingId, trainingBody);
      expectJson(backend().only, 'PUT', '/trainings/$trainingId', trainingBody);
      expect(t.id, trainingId);
    });

    test('getTraining: has_sessions and routine_ids default off/empty; parsed when sent', () async {
      backend().on('GET /trainings/$trainingId', ok(trainingDetailJson));
      final plain = await ctx.api().getTraining(token, trainingId);
      expect(plain.hasSessions, isFalse);
      expect(plain.routineIds, isEmpty);

      backend().on('GET /trainings/$trainingId', ok({...trainingDetailJson, 'has_sessions': true, 'routine_ids': [routineId]}));
      final used = await ctx.api().getTraining(token, trainingId);
      expect(used.hasSessions, isTrue);
      expect(used.routineIds, [routineId]);
    });

    test('getTrainingSuggestions: query, sections and their extras', () async {
      backend().on('GET /trainings/suggestions', ok({
        'recent': [
          {...trainingListJson, 'thumbnail': null, 'last_used_at': '2026-10-28T18:00:00.000Z'},
        ],
        'assigned': [
          {...trainingListJson, 'id': 'a1', 'thumbnail': null, 'routine_name': 'Strength block', 'assigned_by_name': 'Elena Vasquez'},
        ],
        'library': [],
      }));
      final r = await ctx.api().getTrainingSuggestions(token, name: 'core & legs');
      expectGet(backend().only, '/trainings/suggestions', {'limit': '10', 'name': 'core & legs'});
      expect(r.recent.single.training.id, trainingId);
      expect(r.recent.single.lastUsedAt, DateTime.utc(2026, 10, 28, 18));
      expect(r.assigned.single.routineName, 'Strength block');
      expect(r.assigned.single.assignedByName, 'Elena Vasquez');
      expect(r.assigned.single.lastUsedAt, isNull);
      expect(r.library, isEmpty);
      expect(r.isEmpty, isFalse);

      await ctx.api().getTrainingSuggestions(token, name: '', limit: 20);
      expectGet(backend().requests.last, '/trainings/suggestions', {'limit': '20'});
    });

    test('deleteTraining DELETEs /trainings/:id', () async {
      backend().on('DELETE /trainings/$trainingId', ok('', 204));
      await ctx.api().deleteTraining(token, trainingId);
      expectDelete(backend().only, '/trainings/$trainingId');
    });
  });

  group('routines', () {
    test('getRoutines: list shape with thumbnail; filters', () async {
      backend().on('GET /routines', ok([routineListJson]));
      final r = (await ctx.api().getRoutines(token)).single;
      expectGet(backend().requests.last, '/routines', {'page': '0', 'page_size': '20'});
      expect(r.id, routineId);
      expect(r.name, 'Full Body 3x/Week');
      expect(r.scheduleType, RoutineScheduleType.fixedWeeks);
      expect(r.numWeeks, 4);
      expect(r.isPublic, isTrue);
      expect(r.thumbnail!.routineId, routineId);
      expect(r.trainings, isEmpty);

      await ctx.api().getRoutines(token, name: '3x', authorId: elenaId, mine: true, page: 2, pageSize: 5);
      expectGet(backend().requests.last, '/routines', {
        'page': '2',
        'page_size': '5',
        'name': '3x',
        'author_id': elenaId,
        'mine': 'true',
      });
    });

    test('getRoutine parses a wildcard routine without trainings', () async {
      backend().on('GET /routines/$routineId', ok({
        ...routineDetailJson,
        'schedule_type': 'wildcard',
        'num_weeks': null,
        'trainings': [],
      }));
      final r = await ctx.api().getRoutine(token, routineId);
      expectGet(backend().only, '/routines/$routineId');
      expect(r.scheduleType, RoutineScheduleType.wildcard);
      expect(r.numWeeks, isNull);
      expect(r.images.single.isThumbnail, isTrue);
      expect(r.trainings, isEmpty);
    });

    // Each entry's `training` is a summary ({id, name, description,
    // is_public}) without timestamps.
    test('getRoutine parses the real payload with scheduled trainings', () async {
      backend().on('GET /routines/$routineId', ok(routineDetailJson));
      final r = await ctx.api().getRoutine(token, routineId);
      final entry = r.trainings.single;
      expect(entry.id, '03148572-6cc0-4525-8bf7-b5c9d180bb26');
      expect(entry.trainingId, '9318e8ac-468a-4f9f-a08f-815f56c33f1b');
      expect(entry.weekNumber, 1);
      expect(entry.dayOfWeek, 1);
      expect(entry.position, 0);
      expect(entry.note, isNull);
      expect(entry.training!.name, 'Full Body Beginner');
    });

    final routineBody = {
      'name': 'Full Body 3x/Week',
      'description': null,
      'notes': 'Deload on week 4',
      'is_public': false,
      'schedule_type': 'fixed_weeks',
      'num_weeks': 4,
      'images': <Object>[],
      'trainings': [
        {'training_id': trainingId, 'week_number': 1, 'day_of_week': 3, 'position': 0, 'note': null},
      ],
    };
    // A response the model can parse (the real one trips the bug above).
    final routineResponse = {
      ...routineDetailJson,
      'trainings': [
        {...(routineDetailJson['trainings'] as List).single as Map<String, dynamic>, 'training': null},
      ],
    };

    test('createRoutine POSTs the body', () async {
      backend().on('POST /routines', ok(routineResponse, 201));
      final r = await ctx.api().createRoutine(token, routineBody);
      expectJson(backend().only, 'POST', '/routines', routineBody);
      expect(r.trainings.single.training, isNull);
      expect(r.trainings.single.trainingId, '9318e8ac-468a-4f9f-a08f-815f56c33f1b');
    });

    test('updateRoutine PUTs /routines/:id', () async {
      backend().on('PUT /routines/$routineId', ok(routineResponse));
      await ctx.api().updateRoutine(token, routineId, routineBody);
      expectJson(backend().only, 'PUT', '/routines/$routineId', routineBody);
    });

    test('deleteRoutine DELETEs /routines/:id', () async {
      backend().on('DELETE /routines/$routineId', ok('', 204));
      await ctx.api().deleteRoutine(token, routineId);
      expectDelete(backend().only, '/routines/$routineId');
    });
  });

  group('training sessions', () {
    test('getTrainingSessions: defaults and filters', () async {
      backend().on('GET /training-sessions', ok([sessionListJson]));
      final s = (await ctx.api().getTrainingSessions(token)).single;
      expectGet(backend().requests.last, '/training-sessions', {'page': '0', 'page_size': '20'});
      expect(s.id, sessionId);
      expect(s.userId, liamId);
      expect(s.trainerId, isNull);
      expect(s.trainerName, isNull);
      expect(s.trainingId, '5391ad95-91d3-42bc-96f1-22af7f156617');
      expect(s.startedAt, DateTime.utc(2026, 10, 26, 19, 5));
      expect(s.endedAt, DateTime.utc(2026, 10, 26, 20, 37));
      expect(s.setLogs, isEmpty);
      expect(s.commentCount, 0);

      await ctx.api().getTrainingSessions(token, userId: liamId, trainerId: elenaId, trainingId: trainingId, page: 1, pageSize: 50);
      expectGet(backend().requests.last, '/training-sessions', {
        'page': '1',
        'page_size': '50',
        'user_id': liamId,
        'trainer_id': elenaId,
        'training_id': trainingId,
      });

      await ctx.api().getTrainingSessions(token, from: DateTime.utc(2026, 10, 26), to: DateTime.utc(2026, 11, 2));
      expectGet(backend().requests.last, '/training-sessions', {
        'page': '0',
        'page_size': '20',
        'from': '2026-10-26T00:00:00.000Z',
        'to': '2026-11-02T00:00:00.000Z',
      });
    });

    test('a session row carries its training name', () async {
      backend().on('GET /training-sessions', ok([{...sessionListJson, 'training_name': 'Push day'}]));
      expect((await ctx.api().getTrainingSessions(token)).single.trainingName, 'Push day');
      backend().on('GET /training-sessions', ok([sessionListJson]));
      expect((await ctx.api().getTrainingSessions(token)).single.trainingName, isNull);
    });

    test('logPastTrainingSession POSTs the whole session and parses the detail', () async {
      backend().on('POST /training-sessions', ok(sessionDetailJson, 201));
      final data = {
        'training_id': trainingId,
        'started_at': '2026-10-26T19:00:00.000Z',
        'ended_at': '2026-10-26T20:00:00.000Z',
        'notes': null,
        'sets': [
          {
            'training_set_id': null,
            'exercise_id': exerciseId,
            'position': 0,
            'drops': [
              {'training_set_drop_id': null, 'drop_number': 0, 'rep_type_actual': 'count', 'rep_count_actual': 8, 'weight_kg_actual': 40.0, 'side': 'both'},
            ],
          },
        ],
      };
      final s = await ctx.api().logPastTrainingSession(token, data);
      expectJson(backend().only, 'POST', '/training-sessions', data);
      expect(s.setLogs, hasLength(1));
    });

    test('getTrainingSession parses set logs, drop logs and string numbers', () async {
      backend().on('GET /training-sessions/$sessionId', ok(sessionDetailJson));
      final s = await ctx.api().getTrainingSession(token, sessionId);
      expectGet(backend().only, '/training-sessions/$sessionId');
      expect(s.trainerId, elenaId);
      expect(s.trainerName, 'Elena Vasquez');
      expect(s.notes, 'Felt strong');
      expect(s.commentCount, 3);
      final log = s.setLogs.single;
      expect(log.id, '55ef1b3b-eb4d-43b9-a51e-a9d018ccb3d7');
      expect(log.sessionId, sessionId);
      expect(log.trainingSetId, '3b8f5eac-eca3-45bb-9348-6a315f6f2cb2');
      expect(log.exerciseId, isNull);
      expect(log.isPr, isFalse);
      expect(log.prE1rm, isNull);
      expect(log.dropLogs.map((d) => (d.dropNumber, d.repTypeActual, d.repCountActual, d.weightKgActual, d.side)), [
        (0, RepType.count, 8, 105.0, BodySide.both),
        (1, RepType.count, 7, 108.75, BodySide.both),
      ]);
      expect(log.dropLogs.first.trainingSetDropId, '89ad6315-50cf-47db-9062-da191477c638');
    });

    test('getTrainingSession: an open session has no ended_at', () async {
      backend().on('GET /training-sessions/$sessionId', ok({...sessionListJson, 'ended_at': null}));
      expect((await ctx.api().getTrainingSession(token, sessionId)).endedAt, isNull);
    });

    test('startTrainingSession sends all three keys, null when not given', () async {
      backend().on('POST /training-sessions', ok({...sessionListJson, 'ended_at': null}, 201));
      final s = await ctx.api().startTrainingSession(token);
      expectJson(backend().only, 'POST', '/training-sessions', {'training_id': null, 'trainer_id': null, 'notes': null});
      expect(s.endedAt, isNull);

      await ctx.api().startTrainingSession(token, trainingId: trainingId, trainerId: elenaId, notes: 'Leg day');
      expect(bodyOf(backend().requests.last), {'training_id': trainingId, 'trainer_id': elenaId, 'notes': 'Leg day'});
    });

    test('updateTrainingSession PUTs ended_at/notes', () async {
      backend().on('PUT /training-sessions/$sessionId', ok({...sessionListJson, 'notes': 'Done', 'comment_count': 2}));
      final data = {'ended_at': '2026-10-26T20:37:00.000Z', 'notes': 'Done'};
      final s = await ctx.api().updateTrainingSession(token, sessionId, data);
      expectJson(backend().only, 'PUT', '/training-sessions/$sessionId', data);
      expect(s.notes, 'Done');
      expect(s.commentCount, 2);
    });

    test('endTrainingSession POSTs /:id/end without a body', () async {
      backend().on('POST /training-sessions/$sessionId/end', ok(sessionDetailJson));
      final s = await ctx.api().endTrainingSession(token, sessionId);
      expectJson(backend().only, 'POST', '/training-sessions/$sessionId/end', null);
      expect(s.endedAt, DateTime.utc(2026, 10, 26, 20, 37));
      expect(s.setLogs, hasLength(1));
    });

    final setBody = {
      'training_set_id': '3b8f5eac-eca3-45bb-9348-6a315f6f2cb2',
      'position': 0,
      'drops': [
        {
          'training_set_drop_id': '89ad6315-50cf-47db-9062-da191477c638',
          'drop_number': 0,
          'rep_type_actual': 'count',
          'rep_count_actual': 8,
          'weight_kg_actual': 105.0,
          'side': 'both',
          'note': null,
        },
      ],
    };

    test('logSessionSet POSTs /:id/sets and parses the PR fields', () async {
      backend().on('POST /training-sessions/$sessionId/sets', ok({
        ...setLogJson,
        'is_pr': true,
        'pr_e1rm': 132.13,
        'pr_exercise_id': '37be9536-1e89-4d41-93c8-22e71c6b87e9',
        'previous_e1rm': 128.4,
        'prs': [],
      }, 201));
      final log = await ctx.api().logSessionSet(token, sessionId, setBody);
      expectJson(backend().only, 'POST', '/training-sessions/$sessionId/sets', setBody);
      expect(log.isPr, isTrue);
      expect(log.prE1rm, 132.13);
      expect(log.previousE1rm, 128.4);
      expect(log.prExerciseId, '37be9536-1e89-4d41-93c8-22e71c6b87e9');
      expect(log.dropLogs, hasLength(2));
    });

    test('logSessionSet: no PR → nulls', () async {
      backend().on('POST /training-sessions/$sessionId/sets', ok({
        ...setLogJson,
        'is_pr': false,
        'pr_e1rm': null,
        'pr_exercise_id': null,
        'previous_e1rm': null,
      }, 201));
      final log = await ctx.api().logSessionSet(token, sessionId, setBody);
      expect(log.isPr, isFalse);
      expect(log.prE1rm, isNull);
      expect(log.previousE1rm, isNull);
      expect(log.prExerciseId, isNull);
    });

    test('updateSessionSet PUTs /training-sessions/sets/:setLogId', () async {
      const setLogId = '55ef1b3b-eb4d-43b9-a51e-a9d018ccb3d7';
      backend().on('PUT /training-sessions/sets/$setLogId', ok({...setLogJson, 'note': 'Grip slipped'}));
      final data = {'note': 'Grip slipped', 'drops': setBody['drops']};
      final log = await ctx.api().updateSessionSet(token, setLogId, data);
      expectJson(backend().only, 'PUT', '/training-sessions/sets/$setLogId', data);
      expect(log.note, 'Grip slipped');
    });

    test('deleteSessionSet DELETEs /training-sessions/sets/:setLogId', () async {
      backend().on('DELETE /training-sessions/sets/sl-1', ok('', 204));
      await ctx.api().deleteSessionSet(token, 'sl-1');
      expectDelete(backend().only, '/training-sessions/sets/sl-1');
    });

    test('deleteTrainingSession DELETEs /training-sessions/:id', () async {
      backend().on('DELETE /training-sessions/$sessionId', ok('', 204));
      await ctx.api().deleteTrainingSession(token, sessionId);
      expectDelete(backend().only, '/training-sessions/$sessionId');
    });
  });

  group('logSessionSet offline (_sendOrQueue)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await OfflineSupport.outbox.clear();
    });
    tearDown(() => OfflineSupport.outbox.clear());

    test('a network error queues the write (without the token) and throws QueuedOfflineException', () async {
      final seen = <http.Request>[];
      ApiService.debugClientOverride = MockClient((req) async {
        seen.add(req);
        throw const SocketException('Network is unreachable');
      });
      final data = {'training_set_id': 'ts-1', 'position': 2, 'drops': <Object>[]};

      await expectLater(
        ctx.api().logSessionSet(token, sessionId, data),
        throwsA(isA<QueuedOfflineException>()),
      );

      expect(seen, hasLength(1), reason: 'it tried the network first');
      final entry = (await OfflineSupport.outbox.entries()).single;
      expect(entry.method, 'POST');
      expect(entry.url.path, endsWith('/training-sessions/$sessionId/sets'));
      expect(entry.url, seen.single.url);
      expect(entry.headers, {'Content-Type': 'application/json'});
      expect(jsonDecode(entry.body!), data);
      expect(OfflineSupport.outbox.pending.value, 1);
    });

    test('a non-network failure is rethrown and nothing is queued', () async {
      ApiService.debugClientOverride = MockClient((_) async => throw StateError('boom'));
      await expectLater(
        ctx.api().logSessionSet(token, sessionId, {'position': 0}),
        throwsA(isA<StateError>()),
      );
      expect(await OfflineSupport.outbox.entries(), isEmpty);
    });

    test('an HTTP error is not queued; its message surfaces', () async {
      backend().on('POST /training-sessions/$sessionId/sets', err(403, 'Forbidden'));
      await expectLater(ctx.api().logSessionSet(token, sessionId, {'position': 0}), throwsApiError('Forbidden'));
      expect(await OfflineSupport.outbox.entries(), isEmpty);
    });
  });

  errorTests(ctx, {
    'getExercises': ('GET /exercises', (api) => api.getExercises(token)),
    'getExercise': ('GET /exercises/$exerciseId', (api) => api.getExercise(token, exerciseId)),
    'createExercise': ('POST /exercises', (api) => api.createExercise(token, {'name': 'x'})),
    'updateExercise': ('PUT /exercises/$exerciseId', (api) => api.updateExercise(token, exerciseId, {'name': 'x'})),
    'deleteExercise': ('DELETE /exercises/$exerciseId', (api) => api.deleteExercise(token, exerciseId)),
    'getTrainings': ('GET /trainings', (api) => api.getTrainings(token)),
    'getTraining': ('GET /trainings/$trainingId', (api) => api.getTraining(token, trainingId)),
    'createTraining': ('POST /trainings', (api) => api.createTraining(token, {'name': 'x'})),
    'updateTraining': ('PUT /trainings/$trainingId', (api) => api.updateTraining(token, trainingId, {'name': 'x'})),
    'deleteTraining': ('DELETE /trainings/$trainingId', (api) => api.deleteTraining(token, trainingId)),
    'getRoutines': ('GET /routines', (api) => api.getRoutines(token)),
    'getRoutine': ('GET /routines/$routineId', (api) => api.getRoutine(token, routineId)),
    'createRoutine': ('POST /routines', (api) => api.createRoutine(token, {'name': 'x'})),
    'updateRoutine': ('PUT /routines/$routineId', (api) => api.updateRoutine(token, routineId, {'name': 'x'})),
    'deleteRoutine': ('DELETE /routines/$routineId', (api) => api.deleteRoutine(token, routineId)),
    'getTrainingSessions': ('GET /training-sessions', (api) => api.getTrainingSessions(token)),
    'getTrainingSession': ('GET /training-sessions/$sessionId', (api) => api.getTrainingSession(token, sessionId)),
    'startTrainingSession': ('POST /training-sessions', (api) => api.startTrainingSession(token)),
    'updateTrainingSession': (
      'PUT /training-sessions/$sessionId',
      (api) => api.updateTrainingSession(token, sessionId, {'notes': 'x'}),
    ),
    'endTrainingSession': ('POST /training-sessions/$sessionId/end', (api) => api.endTrainingSession(token, sessionId)),
    'logSessionSet': ('POST /training-sessions/$sessionId/sets', (api) => api.logSessionSet(token, sessionId, {'position': 0})),
    'updateSessionSet': ('PUT /training-sessions/sets/sl-1', (api) => api.updateSessionSet(token, 'sl-1', {'note': 'x'})),
    'deleteSessionSet': ('DELETE /training-sessions/sets/sl-1', (api) => api.deleteSessionSet(token, 'sl-1')),
    'deleteTrainingSession': ('DELETE /training-sessions/$sessionId', (api) => api.deleteTrainingSession(token, sessionId)),
  });
}

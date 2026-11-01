import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/progress.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

// Shapes captured from the local stack (GET /body-measurements, /progress-photos as liam).
Map<String, dynamic> _measurementJson() => {
      'id': 'bm1',
      'user_id': 'u-liam',
      'measured_on': '2026-10-28',
      'weight_kg': '80.5', // numerics may arrive as strings
      'body_fat_pct': null,
      'waist_cm': 84.3,
      'chest_cm': '101',
      'hips_cm': null,
      'arm_cm': 36,
      'thigh_cm': null,
      'neck_cm': '38.5',
      'note': null,
      'created_at': '2026-10-28T06:40:00.000Z',
    };

Map<String, dynamic> _photoJson({
  String id = 'ph1',
  String pose = 'side',
  String takenOn = '2026-10-10',
  Object? weight = 79.4,
  String? createdAt = '2026-10-10T07:00:00.000Z',
}) =>
    {
      'id': id,
      'user_id': 'u-liam',
      'pose': pose,
      'taken_on': takenOn,
      'weight_kg': weight,
      'note': 'day 1',
      'created_at': createdAt,
      'url': '/storage/v1/object/sign/progress-photos/u-liam/$id.jpg?token=abc',
    };

ProgressPhoto _photo(String id, ProgressPose pose, DateTime takenOn) => ProgressPhoto(
      id: id,
      userId: 'u',
      pose: pose,
      takenOn: takenOn,
      createdAt: takenOn,
    );

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('BodyMeasurement tape fields', () {
    test('parse numbers and numeric strings, keep nulls', () async {
      backend.on('GET /body-measurements', ok([_measurementJson()]));
      final m = (await api.getBodyMeasurements(_token)).single;
      expect(m.measuredOn, DateTime(2026, 10, 28));
      expect(m.weightKg, 80.5);
      expect(m.waistCm, 84.3);
      expect(m.chestCm, 101);
      expect(m.hipsCm, isNull);
      expect(m.armCm, 36);
      expect(m.neckCm, 38.5);
      expect(m.hasTape, isTrue);
      expect(BodyMetric.waist.valueOf(m), 84.3);
      expect(BodyMetric.bodyFat.valueOf(m), isNull);
      expect(BodyMetric.weight.isLength, isFalse);
      expect(BodyMetric.neck.isLength, isTrue);
      expect([for (final t in BodyMetric.tape) t.apiKey], ['waist_cm', 'chest_cm', 'hips_cm', 'arm_cm', 'thigh_cm', 'neck_cm']);
    });

    test('old rows without tape columns still parse', () async {
      backend.on('GET /body-measurements', ok([
        {'id': 'bm0', 'user_id': 'u', 'measured_on': '2026-08-11', 'weight_kg': 75.2, 'body_fat_pct': '18.5', 'note': null},
      ]));
      final m = (await api.getBodyMeasurements(_token)).single;
      expect(m.weightKg, 75.2);
      expect(m.bodyFatPct, 18.5);
      expect(m.hasTape, isFalse);
    });

    test('create sends tape fields as given', () async {
      backend.on('POST /body-measurements', ok(_measurementJson(), 201));
      await api.createBodyMeasurement(_token, {'measured_on': '2026-10-28', 'waist_cm': 84.3, 'neck_cm': null});
      expect(bodyOf(backend.only), {'measured_on': '2026-10-28', 'waist_cm': 84.3, 'neck_cm': null});
    });
  });

  group('progress photos', () {
    test('list: no query by default, parses and resolves the signed URL', () async {
      backend.on('GET /progress-photos', ok([_photoJson(weight: '79.40')]));
      final p = (await api.getProgressPhotos(_token)).single;
      final req = backend.only;
      expect(req.headers['Authorization'], 'Bearer $_token');
      expect(req.url.hasQuery, isFalse);
      expect(p.id, 'ph1');
      expect(p.pose, ProgressPose.side);
      expect(p.takenOn, DateTime(2026, 10, 10));
      expect(p.weightKg, 79.4);
      expect(p.note, 'day 1');
      expect(p.url, '${AppConfig.supabaseOrigin}/storage/v1/object/sign/progress-photos/u-liam/ph1.jpg?token=abc');
    });

    test('list: pose and date filters', () async {
      backend.on('GET /progress-photos', ok([]));
      await api.getProgressPhotos(_token, pose: ProgressPose.back, from: DateTime(2026, 1, 5), to: DateTime(2026, 2, 1));
      expect(backend.only.url.queryParameters, {'pose': 'back', 'from': '2026-01-05', 'to': '2026-02-01'});
    });

    test('unknown pose falls back to other; missing url is null', () {
      final p = ProgressPhoto.fromJson({..._photoJson(pose: 'selfie'), 'url': null});
      expect(p.pose, ProgressPose.other);
      expect(p.url, isNull);
    });

    test('upload slot request', () async {
      backend.on('POST /progress-photos/uploads', ok({
        'path': 'u-liam/x.jpg',
        'upload_url': '/storage/v1/object/upload/sign/progress-photos/u-liam/x.jpg?token=t',
        'token': 't',
        'mime_type': 'image/jpeg',
        'expires_in': 7200,
      }, 201));
      final slot = await api.requestProgressPhotoUpload(_token, mimeType: 'image/jpeg', sizeBytes: 1234, fileName: 'x.jpg');
      expect(bodyOf(backend.only), {'mime_type': 'image/jpeg', 'size_bytes': 1234, 'file_name': 'x.jpg'});
      expect(slot.path, 'u-liam/x.jpg');
      expect(slot.uploadUrl, startsWith(AppConfig.supabaseOrigin));
    });

    test('create omits weight (server snapshots it) and blank notes', () async {
      backend.on('POST /progress-photos', ok(_photoJson(), 201));
      await api.createProgressPhoto(_token, path: 'u/x.jpg', pose: ProgressPose.front, takenOn: DateTime(2026, 10, 10), note: '  ');
      expect(bodyOf(backend.only), {'path': 'u/x.jpg', 'pose': 'front', 'taken_on': '2026-10-10'});
    });

    test('create with a weight and note', () async {
      backend.on('POST /progress-photos', ok(_photoJson(), 201));
      await api.createProgressPhoto(_token, path: 'u/x.jpg', pose: ProgressPose.side, takenOn: DateTime(2026, 1, 2), weightKg: 80.25, note: ' wk 1 ');
      expect(bodyOf(backend.only), {'path': 'u/x.jpg', 'pose': 'side', 'taken_on': '2026-01-02', 'weight_kg': 80.25, 'note': 'wk 1'});
    });

    test('update and delete', () async {
      backend.on('PUT /progress-photos/ph1', ok(_photoJson(pose: 'back')));
      backend.on('DELETE /progress-photos/ph1', ok(null, 204));
      final p = await api.updateProgressPhoto(_token, 'ph1', {'pose': 'back'});
      expect(p.pose, ProgressPose.back);
      await api.deleteProgressPhoto(_token, 'ph1');
      expect(backend.requests.map(describe), ['PUT /progress-photos/ph1', 'DELETE /progress-photos/ph1']);
    });

    test('delete surfaces API errors', () async {
      backend.on('DELETE /progress-photos/nope', err(404, 'Photo not found'));
      expect(api.deleteProgressPhoto(_token, 'nope'), throwsA(predicate((e) => '$e'.contains('Photo not found'))));
    });
  });

  group('photo helpers', () {
    test('defaultComparePair: oldest vs newest of the newest photo\'s pose', () {
      final photos = [
        _photo('f1', ProgressPose.front, DateTime(2026, 1, 1)),
        _photo('s1', ProgressPose.side, DateTime(2026, 2, 1)),
        _photo('f2', ProgressPose.front, DateTime(2026, 3, 1)),
        _photo('f3', ProgressPose.front, DateTime(2026, 6, 1)),
        _photo('s2', ProgressPose.side, DateTime(2026, 5, 1)),
      ];
      final pair = defaultComparePair(photos)!;
      expect(pair.before.id, 'f1');
      expect(pair.after.id, 'f3');
    });

    test('defaultComparePair: falls back to oldest vs newest overall', () {
      final photos = [
        _photo('f1', ProgressPose.front, DateTime(2026, 1, 1)),
        _photo('s1', ProgressPose.side, DateTime(2026, 2, 1)),
        _photo('b1', ProgressPose.back, DateTime(2026, 3, 1)),
      ];
      final pair = defaultComparePair(photos)!;
      expect(pair.before.id, 'f1');
      expect(pair.after.id, 'b1');
      expect(defaultComparePair([photos.first]), isNull);
      expect(defaultComparePair(const []), isNull);
    });

    test('groupProgressPhotosByMonth: newest month and photo first', () {
      final groups = groupProgressPhotosByMonth([
        _photo('a', ProgressPose.front, DateTime(2026, 9, 3)),
        _photo('b', ProgressPose.front, DateTime(2026, 10, 20)),
        _photo('c', ProgressPose.side, DateTime(2026, 10, 2)),
        _photo('d', ProgressPose.back, DateTime(2025, 10, 9)),
      ]);
      expect([for (final g in groups) g.month], [DateTime(2026, 10), DateTime(2026, 9), DateTime(2025, 10)]);
      expect([for (final p in groups.first.photos) p.id], ['b', 'c']);
      expect(groupProgressPhotosByMonth(const []), isEmpty);
    });
  });
}

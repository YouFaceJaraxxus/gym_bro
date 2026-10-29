import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/media_editor/media_edit.dart';
import 'package:gym_bro_mobile/models/draft.dart';

/// Applies a 4×5 matrix to an opaque RGB pixel (0…255), like Flutter does.
List<double> apply(List<double> m, List<double> rgb) => [
  for (var row = 0; row < 3; row++)
    (m[row * 5] * rgb[0] + m[row * 5 + 1] * rgb[1] + m[row * 5 + 2] * rgb[2] + m[row * 5 + 3] * 255 + m[row * 5 + 4])
        .clamp(0, 255)
        .toDouble(),
];

void main() {
  group('ColorMatrix', () {
    test('chaining applies in order', () {
      final a = ColorMatrix.brightness(0.5);
      final b = ColorMatrix.saturation(-1);
      final pixel = [200.0, 40.0, 90.0];
      final step = apply(b, apply(a, pixel));
      final chained = apply(ColorMatrix.then(a, b), pixel);
      for (var i = 0; i < 3; i++) {
        expect(chained[i], closeTo(step[i], 1e-6));
      }
    });

    test('saturation −1 is grayscale, contrast keeps mid-gray', () {
      final gray = apply(ColorMatrix.saturation(-1), [200, 40, 90]);
      expect(gray[0], closeTo(gray[1], 1e-6));
      expect(gray[1], closeTo(gray[2], 1e-6));
      final mid = apply(ColorMatrix.contrast(0.8), [127.5, 127.5, 127.5]);
      expect(mid[0], closeTo(127.5, 1e-6));
    });

    test('warmth shifts red up and blue down', () {
      final warm = apply(ColorMatrix.warmth(1), [128, 128, 128]);
      expect(warm[0], greaterThan(128));
      expect(warm[1], 128);
      expect(warm[2], lessThan(128));
    });

    test('blend 0 is identity, 1 is the filter', () {
      final sepia = ColorMatrix.sepia;
      expect(ColorMatrix.isIdentity(ColorMatrix.blend(sepia, 0)), isTrue);
      expect(ColorMatrix.blend(sepia, 1), sepia);
    });
  });

  group('MediaEdit', () {
    test('none is identity with no color matrix', () {
      expect(MediaEdit.none.isIdentity, isTrue);
      expect(MediaEdit.none.hasColorMatrix, isFalse);
      expect(MediaEdit.none.withFilter('normal', 1).isIdentity, isTrue);
    });

    test('vignette alone needs no color matrix but is an edit', () {
      final e = MediaEdit.none.withAdjustment(Adjustment.vignette, 0.4);
      expect(e.isIdentity, isFalse);
      expect(e.hasColorMatrix, isFalse);
    });

    test('setting an adjustment back to 0 removes it', () {
      final e = MediaEdit.none.withAdjustment(Adjustment.contrast, 0.3).withAdjustment(Adjustment.contrast, 0);
      expect(e.adjust, isEmpty);
      expect(e, MediaEdit.none);
    });

    test('JSON round-trips', () {
      final e = MediaEdit.none
          .withFilter('vintage', 0.6)
          .withAdjustment(Adjustment.brightness, -0.25)
          .withAdjustment(Adjustment.fade, 0.5)
          .withTrim(const Duration(milliseconds: 1500), const Duration(seconds: 9));
      final back = MediaEdit.fromJson(e.toJson());
      expect(back, e);
      expect(back.hashCode, e.hashCode);
    });

    test('fromJson tolerates junk from older or newer apps', () {
      final e = MediaEdit.fromJson({
        'filter': 'does-not-exist',
        'filter_strength': 'abc',
        'adjust': {'brightness': '0.5', 'warmth': 7, 'fade': -1, 'sharpen': 0.3},
        'trim_start_ms': '2000',
        'trim_end_ms': 1000,
      });
      expect(e.filter, 'normal');
      expect(e.value(Adjustment.brightness), 0.5);
      expect(e.value(Adjustment.warmth), 1); // clamped
      expect(e.value(Adjustment.fade), 0); // one-sided, clamped to 0
      expect(e.trimStart, const Duration(seconds: 2));
      expect(e.trimEnd! > e.trimStart!, isTrue);
      expect(MediaEdit.fromJson(null), MediaEdit.none);
    });

    test('withLookOf keeps the trim, sameLook ignores it', () {
      final video = MediaEdit.none.withTrim(const Duration(seconds: 1), const Duration(seconds: 4));
      final look = MediaEdit.none.withFilter('mono', 1).withAdjustment(Adjustment.contrast, 0.2);
      final combined = video.withLookOf(look);
      expect(combined.trimStart, const Duration(seconds: 1));
      expect(combined.sameLook(look), isTrue);
      expect(combined == look, isFalse);
    });
  });

  group('EditHistory', () {
    test('undo steps back one setting without touching the others', () {
      final h = EditHistory();
      var e = MediaEdit.none;
      void change(EditSetting s, MediaEdit next) {
        h.record(s, e, next);
        e = next;
      }

      change(const AdjustSetting(Adjustment.brightness), e.withAdjustment(Adjustment.brightness, 0.2));
      change(const AdjustSetting(Adjustment.brightness), e.withAdjustment(Adjustment.brightness, 0.5));
      change(const FilterSetting(), e.withFilter('golden', 1));
      change(const AdjustSetting(Adjustment.contrast), e.withAdjustment(Adjustment.contrast, -0.4));

      e = h.undo(const AdjustSetting(Adjustment.brightness), e);
      expect(e.value(Adjustment.brightness), 0.2);
      expect(e.filter, 'golden');
      expect(e.value(Adjustment.contrast), -0.4);

      e = h.undo(const AdjustSetting(Adjustment.brightness), e);
      expect(e.value(Adjustment.brightness), 0);
      expect(h.canUndo(const AdjustSetting(Adjustment.brightness)), isFalse);
      expect(h.canUndo(const FilterSetting()), isTrue);
    });

    test('no-op changes are not recorded; reset is undoable', () {
      final h = EditHistory();
      const s = AdjustSetting(Adjustment.saturation);
      final e = MediaEdit.none.withAdjustment(Adjustment.saturation, 0.3);
      h.record(s, e, e);
      expect(h.canUndo(s), isFalse);

      final reset = EditHistory.reset(s, e);
      expect(reset.value(Adjustment.saturation), 0);
      h.record(s, e, reset);
      expect(h.undo(s, reset).value(Adjustment.saturation), 0.3);
    });

    test('trim undo and reset', () {
      final h = EditHistory();
      const s = TrimSetting();
      final trimmed = MediaEdit.none.withFilter('rose', 1).withTrim(const Duration(seconds: 2), const Duration(seconds: 5));
      final reset = EditHistory.reset(s, trimmed);
      expect(reset.hasTrim, isFalse);
      expect(reset.filter, 'rose');
      h.record(s, trimmed, reset);
      expect(h.undo(s, reset).trimStart, const Duration(seconds: 2));
    });
  });

  group('Draft model', () {
    test('parses a draft with media and resolves relative URLs', () {
      final d = Draft.fromJson({
        'id': 'd1',
        'kind': 'post',
        'scope_id': null,
        'title': 'Beach day',
        'thumbnail_url': '/storage/v1/object/sign/user-media/u/a.jpg?token=x',
        'media_count': 1,
        'has_video': false,
        'created_at': '2026-10-29T10:00:00Z',
        'updated_at': '2026-10-29T10:05:00Z',
        'data': {'caption': 'Beach day', 'visibility': 'followers'},
        'media': [
          {
            'path': 'u/a.jpg',
            'mime_type': 'image/jpeg',
            'width': '1080',
            'height': 1350,
            'edit': {'filter': 'vivid'},
            'url': '/storage/v1/object/sign/user-media/u/a.jpg?token=x',
          },
        ],
      });
      expect(d.kind, DraftKind.post);
      expect(d.thumbnailUrl, startsWith('http'));
      expect(d.data['visibility'], 'followers');
      expect(d.media.single.width, 1080);
      expect(MediaEdit.fromJson(d.media.single.edit).filter, 'vivid');
      expect(d.media.single.toJson(), containsPair('path', 'u/a.jpg'));
    });

    test('every kind maps to its API value and back', () {
      for (final k in DraftKind.values) {
        expect(DraftKind.fromApi(k.apiValue), k);
      }
    });
  });
}

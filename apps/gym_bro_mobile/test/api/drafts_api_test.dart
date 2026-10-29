import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/draft.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

Map<String, Object?> draftJson({String id = 'd1', Map<String, Object?> data = const {}}) => {
  'id': id,
  'kind': 'business_post',
  'scope_id': 'b1',
  'title': 'Hello',
  'thumbnail_url': null,
  'media_count': 0,
  'has_video': false,
  'created_at': '2026-10-29T10:00:00Z',
  'updated_at': '2026-10-29T10:00:00Z',
  'data': data,
  'media': <Object?>[],
};

void main() {
  final t = useFakeBackend();

  test('lists drafts of a kind, scoped', () async {
    t.backend().on('GET /drafts', ok([draftJson()]));
    final drafts = await t.api().getDrafts(token, DraftKind.businessPost, scopeId: 'b1');
    expectGet(t.backend().only, '/drafts', {'kind': 'business_post', 'scope_id': 'b1'});
    expect(drafts.single.scopeId, 'b1');
  });

  test('creates a draft with kind and scope, updates without them', () async {
    t.backend().on('POST /drafts', ok(draftJson(data: {'content': 'x'}), 201));
    t.backend().on('PUT /drafts/d1', ok(draftJson(data: {'content': 'y'})));
    final created = await t.api().saveDraft(token, kind: DraftKind.businessPost, scopeId: 'b1', title: 'Hello', data: {'content': 'x'});
    expectJson(t.backend().last('POST /drafts'), 'POST', '/drafts', {
      'kind': 'business_post',
      'scope_id': 'b1',
      'title': 'Hello',
      'data': {'content': 'x'},
      'media': <Object?>[],
    });
    expect(created.data['content'], 'x');

    await t.api().saveDraft(
      token,
      id: 'd1',
      kind: DraftKind.businessPost,
      scopeId: 'b1',
      data: {'content': 'y'},
      media: const [DraftMedia(path: 'u/a.jpg', mimeType: 'image/jpeg', width: 10, edit: {'filter': 'mono'})],
    );
    expectJson(t.backend().last('PUT /drafts/d1'), 'PUT', '/drafts/d1', {
      'data': {'content': 'y'},
      'media': [
        {'path': 'u/a.jpg', 'width': 10, 'edit': {'filter': 'mono'}},
      ],
    });
  });

  test('delete ignores an already-deleted draft, surfaces other errors', () async {
    t.backend().on('DELETE /drafts/gone', err(404, 'Draft not found'));
    await t.api().deleteDraft(token, 'gone');
    expectDelete(t.backend().only, '/drafts/gone');

    t.backend().on('DELETE /drafts/x', err(500, 'boom'));
    expect(ApiService().deleteDraft(token, 'x'), throwsApiError('boom'));
  });
}

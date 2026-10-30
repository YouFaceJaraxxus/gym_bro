// Mention markup (same grammar as the API's _shared/mentions.ts) and the
// composer's MentionTextEditingController: "@Name" on screen, markup stored.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/mention.dart';
import 'package:gym_bro_mobile/widgets/mentions.dart';

const _elenaId = 'f591534f-a631-4b71-9fd4-b8260e6f3ee6';
const _gymId = '0b7a2c1e-1111-4b71-9fd4-b8260e6f3ee6';
const _itemId = '7e670926-c65c-45e0-aa7b-e5e1cdb0fb9e';

const _elena = Mention(kind: MentionKind.user, id: _elenaId, label: 'Elena Vasquez');
const _gym = Mention(kind: MentionKind.business, id: _gymId, label: 'Ironclad Fitness');

/// Types [text] at the cursor, as the platform would (one value per edit).
void _type(TextEditingController c, String text) {
  final sel = c.selection;
  final at = sel.isValid ? sel.baseOffset : c.text.length;
  c.value = TextEditingValue(
    text: c.text.substring(0, at) + text + c.text.substring(at),
    selection: TextSelection.collapsed(offset: at + text.length),
  );
}

/// Backspace at the cursor.
void _backspace(TextEditingController c) {
  final at = c.selection.baseOffset;
  c.value = TextEditingValue(
    text: c.text.substring(0, at - 1) + c.text.substring(at),
    selection: TextSelection.collapsed(offset: at - 1),
  );
}

void _cursorAt(TextEditingController c, int offset) => c.selection = TextSelection.collapsed(offset: offset);

void main() {
  group('markup', () {
    test('parses mentions of every kind between plain text', () {
      final segs = parseMentions('PR with @[Elena Vasquez](user:$_elenaId) at @[Ironclad Fitness](business:$_gymId), '
          'fuelled by @[Whey](shop_item:$_itemId)!');
      expect(segs.map((s) => s.text).join(), 'PR with @Elena Vasquez at @Ironclad Fitness, fuelled by @Whey!');
      final mentions = segs.where((s) => s.isMention).map((s) => s.mention!).toList();
      expect(mentions.map((m) => m.kind), [MentionKind.user, MentionKind.business, MentionKind.shopItem]);
      expect(mentions.first, _elena);
    });

    test('leaves malformed markup, emails and plain @handles as text', () {
      const text = 'mail me@x.com, @liam, @[Bad](user:not-a-uuid) @[Nope](team:$_elenaId)';
      expect(parseMentions(text).single.text, text);
      expect(hasMentions(text), isFalse);
      expect(mentionPlainText(text), text);
    });

    test('plain text shows mentions as @Name', () {
      expect(mentionPlainText('hi @[Elena Vasquez](user:$_elenaId)!'), 'hi @Elena Vasquez!');
    });

    test('labels are sanitized for markup', () {
      const m = Mention(kind: MentionKind.user, id: _elenaId, label: ' Ana ]Bell\n ');
      expect(m.markup, '@[Ana Bell](user:$_elenaId)');
      expect(parseMentions(m.markup).single.mention!.label, 'Ana Bell');
    });

    test('suggestion rows parse; unknown kinds are skipped', () {
      final s = MentionSuggestion.maybeFromJson({
        'kind': 'business',
        'id': _gymId,
        'label': 'Ironclad Fitness',
        'subtitle': 'Knez Mihailova 1',
        'business_type': 'gym',
        'image_url': null,
      })!;
      expect(s.kind, MentionKind.business);
      expect(s.businessType, 'gym');
      expect(s.mention, _gym);
      expect(MentionSuggestion.maybeFromJson({'kind': 'team', 'id': 'x', 'label': 'A'}), isNull);
      // A person without a name falls back to the username.
      expect(MentionSuggestion.maybeFromJson({'kind': 'user', 'id': _elenaId, 'label': '', 'username': 'elena'})!.label, 'elena');
    });
  });

  group('MentionTextEditingController', () {
    test('round-trips markup: "@Name" shown, markup stored', () {
      const stored = 'Squats with @[Elena Vasquez](user:$_elenaId) at @[Ironclad Fitness](business:$_gymId) 💪';
      final c = MentionTextEditingController(markup: stored);
      expect(c.text, 'Squats with @Elena Vasquez at @Ironclad Fitness 💪');
      expect(c.markup, stored);
      expect(c.mentions.map((m) => m.mention), [_elena, _gym]);
      expect(c.selection.baseOffset, c.text.length);
    });

    test('mentionQuery finds the "@word" being typed', () {
      final c = MentionTextEditingController();
      _type(c, 'hey @');
      expect(c.mentionQuery, (start: 4, query: ''));
      _type(c, 'el');
      expect(c.mentionQuery, (start: 4, query: 'el'));
      _type(c, ' ');
      expect(c.mentionQuery, isNull, reason: 'a space ends the query');
      c.markup = 'mail me@x';
      expect(c.mentionQuery, isNull, reason: '"@" must start a word');
    });

    test('insertMention replaces the query and adds a space', () {
      final c = MentionTextEditingController();
      _type(c, 'Leg day with @el');
      c.insertMention(_elena);
      expect(c.text, 'Leg day with @Elena Vasquez ');
      expect(c.selection.baseOffset, c.text.length);
      expect(c.markup, 'Leg day with @[Elena Vasquez](user:$_elenaId) ');
      expect(c.mentionQuery, isNull);
    });

    test('insertMention in the middle shifts later mentions and reuses a following space', () {
      final c = MentionTextEditingController(markup: 'with  and @[Ironclad Fitness](business:$_gymId)');
      _cursorAt(c, 5);
      _type(c, '@E');
      c.insertMention(_elena);
      expect(c.text, 'with @Elena Vasquez and @Ironclad Fitness');
      expect(c.markup, 'with @[Elena Vasquez](user:$_elenaId) and @[Ironclad Fitness](business:$_gymId)');
      expect(c.selection.baseOffset, 'with @Elena Vasquez '.length);
    });

    test('typing before a mention shifts it; typing right after leaves it whole', () {
      final c = MentionTextEditingController(markup: '@[Elena Vasquez](user:$_elenaId)');
      _cursorAt(c, 0);
      _type(c, 'Hi ');
      _cursorAt(c, c.text.length);
      _type(c, '!');
      expect(c.text, 'Hi @Elena Vasquez!');
      expect(c.markup, 'Hi @[Elena Vasquez](user:$_elenaId)!');
    });

    test('typing inside a mention turns it into plain text', () {
      final c = MentionTextEditingController(markup: 'x @[Elena Vasquez](user:$_elenaId) y @[Ironclad Fitness](business:$_gymId)');
      _cursorAt(c, 8); // after "@Elena"
      _type(c, 'X');
      expect(c.text, 'x @ElenaX Vasquez y @Ironclad Fitness');
      expect(c.markup, 'x @ElenaX Vasquez y @[Ironclad Fitness](business:$_gymId)');
    });

    test('backspacing into a mention deletes it whole', () {
      final c = MentionTextEditingController(markup: 'go @[Elena Vasquez](user:$_elenaId) and @[Ironclad Fitness](business:$_gymId)');
      _cursorAt(c, 'go @Elena Vasquez'.length);
      _backspace(c);
      expect(c.text, 'go  and @Ironclad Fitness');
      expect(c.selection.baseOffset, 3);
      expect(c.markup, 'go  and @[Ironclad Fitness](business:$_gymId)');
    });

    test('deleting a selection that overlaps a mention takes the mention too', () {
      final c = MentionTextEditingController(markup: 'ab @[Elena Vasquez](user:$_elenaId) cd');
      // Select "b @Ele" and delete it.
      c.value = const TextEditingValue(text: 'anVasquez cd', selection: TextSelection.collapsed(offset: 1));
      expect(c.text, 'a cd');
      expect(c.mentions, isEmpty);
    });

    test('replacing text across a mention (autocorrect) keeps the new text plain', () {
      final c = MentionTextEditingController(markup: '@[Elena Vasquez](user:$_elenaId) rocks');
      c.value = const TextEditingValue(text: 'Elena rocks', selection: TextSelection.collapsed(offset: 5));
      expect(c.mentions, isEmpty);
      expect(c.markup, 'Elena rocks');
    });

    test('deleting text before a mention shifts it', () {
      final c = MentionTextEditingController(markup: 'hello @[Elena Vasquez](user:$_elenaId)');
      _cursorAt(c, 5);
      _backspace(c);
      expect(c.markup, 'hell @[Elena Vasquez](user:$_elenaId)');
    });

    test('clear() drops mentions', () {
      final c = MentionTextEditingController(markup: '@[Elena Vasquez](user:$_elenaId)');
      c.clear();
      expect(c.text, isEmpty);
      expect(c.mentions, isEmpty);
      _type(c, 'plain');
      expect(c.markup, 'plain');
    });

    testWidgets('buildTextSpan styles mentions', (tester) async {
      final c = MentionTextEditingController(markup: 'hi @[Elena Vasquez](user:$_elenaId)');
      late TextSpan span;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        span = c.buildTextSpan(context: context, style: const TextStyle(), withComposing: false);
        return const SizedBox();
      })));
      final children = span.children!.cast<TextSpan>();
      expect(children.map((s) => s.text), ['hi ', '@Elena Vasquez']);
      expect(children.last.style!.fontWeight, FontWeight.w600);
    });
  });
}

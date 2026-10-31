import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/story.dart';

// The poll sticker, Instagram-style: a white card with the question and 2–4
// options. Before I vote the options are buttons; afterwards (and always for
// the author) each shows its share of the votes, my choice highlighted.

const _pollAccent = Color(0xFF3A86FF);

/// A story's poll. [onVote] makes the options tappable (someone else's live
/// story); results show once [StoryPoll.hasResults].
class StoryPollSticker extends StatelessWidget {
  const StoryPollSticker({super.key, required this.poll, this.onVote, this.maxWidth = 300});

  final StoryPoll poll;
  final ValueChanged<int>? onVote;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = poll.hasResults;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (poll.question.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  poll.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            for (final (i, option) in poll.options.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              results ? _ResultRow(poll: poll, index: i, label: option) : _OptionButton(label: option, onTap: onVote == null ? null : () => onVote!(i)),
            ],
            if (results) ...[
              const SizedBox(height: 8),
              Text(
                l10n.storyPollVotes(poll.total ?? 0),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(12)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _pollAccent, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.poll, required this.index, required this.label});

  final StoryPoll poll;
  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mine = poll.myVote == index;
    final pct = poll.percent(index);
    return Semantics(
      selected: mine,
      label: '$label, $pct%',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          Positioned.fill(child: Container(color: const Color(0xFFF1F2F6))),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: poll.fraction(index).clamp(0.0, 1.0),
              child: Container(color: mine ? _pollAccent.withValues(alpha: 0.35) : Colors.black12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              if (mine) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, size: 16, color: _pollAccent)),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: mine ? FontWeight.w800 : FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text('$pct%', style: TextStyle(color: mine ? _pollAccent : Colors.black54, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The poll sticker editor: an optional question and 2–4 options. Returns
/// the poll, or null when cancelled.
Future<StoryPoll?> showStoryPollEditor(BuildContext context, {StoryPoll? initial}) =>
    showDialog<StoryPoll>(context: context, builder: (_) => _PollEditor(initial: initial));

class _PollEditor extends StatefulWidget {
  const _PollEditor({this.initial});

  final StoryPoll? initial;

  @override
  State<_PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends State<_PollEditor> {
  static const _maxOptions = 4;
  late final _question = TextEditingController(text: widget.initial?.question ?? '');
  late final List<TextEditingController> _options = [
    for (final o in widget.initial?.options ?? const ['', '']) TextEditingController(text: o),
  ];
  bool _tried = false;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    final options = [for (final c in _options) c.text.trim()];
    if (options.length < 2 || options.any((o) => o.isEmpty)) {
      setState(() => _tried = true);
      return;
    }
    Navigator.pop(context, StoryPoll(question: _question.text.trim(), options: options));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.storyPollEditorTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const ValueKey('story-poll-question'),
            controller: _question,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.storyPollQuestionHint),
          ),
          for (final (i, c) in _options.indexed)
            Padding(
              key: ObjectKey(c),
              padding: const EdgeInsets.only(top: 4),
              child: TextField(
                key: ValueKey('story-poll-option-$i'),
                controller: c,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.storyPollOptionLabel(i + 1),
                  errorText: _tried && c.text.trim().isEmpty ? l10n.commonRequired : null,
                  counterText: '',
                  suffixIcon: _options.length > 2
                      ? IconButton(
                          tooltip: l10n.storyPollRemoveOption,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            final removed = _options.removeAt(i);
                            setState(() {});
                            WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                          },
                        )
                      : null,
                ),
              ),
            ),
          if (_options.length < _maxOptions)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: Text(l10n.storyPollAddOption),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _done, child: Text(l10n.storyPollDone)),
      ],
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../l10n/l10n.dart';
import '../../services/media_upload.dart';
import '../../widgets/social_widgets.dart';
import 'chat_widgets.dart';

/// Voice messages: AAC-LC .m4a recorded into a temp file, sent through the
/// normal chat upload flow as audio/mp4 with its duration.

/// Shorter than this is a mis-tap, not a message.
const _minDuration = Duration(milliseconds: 800);

/// Recording stops (and sends) on its own after this long.
const _maxDuration = Duration(minutes: 5);

/// Replaces the composer row while recording: [discard] ● 0:07 [send].
/// Starts recording when shown; [onSend] gets the finished file, [onClose]
/// runs whenever the bar should go away (sent, discarded or failed).
class VoiceRecorderBar extends StatefulWidget {
  const VoiceRecorderBar({super.key, required this.onSend, required this.onClose});

  final ValueChanged<PickedMedia> onSend;
  final VoidCallback onClose;

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: _start reads localizations from context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    if (!_done && _startedAt != null) _recorder.cancel().catchError((_) {});
    _recorder.dispose().catchError((_) {});
    super.dispose();
  }

  void _fail(String text) {
    if (!mounted) return;
    showChatSnack(context, text);
    _done = true;
    widget.onClose();
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    try {
      if (!await _recorder.hasPermission()) return _fail(l10n.chatVoicePermission);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      if (!mounted) return;
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1), path: path);
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final at = _startedAt;
        if (at == null || !mounted) return;
        setState(() => _elapsed = DateTime.now().difference(at));
        if (_elapsed >= _maxDuration) _send();
      });
    } catch (_) {
      _fail(l10n.chatVoiceFailed);
    }
  }

  Future<void> _discard() async {
    if (_done) return;
    _done = true;
    _ticker?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    widget.onClose();
  }

  Future<void> _send() async {
    if (_done || _startedAt == null) return;
    final l10n = context.l10n;
    _done = true;
    _ticker?.cancel();
    final duration = DateTime.now().difference(_startedAt!);
    try {
      final path = await _recorder.stop();
      if (path == null) return _fail(l10n.chatVoiceFailed);
      final file = File(path);
      if (duration < _minDuration) {
        try {
          await file.delete();
        } catch (_) {}
        return _fail(l10n.chatVoiceTooShort);
      }
      final media = PickedMedia(
        file: file,
        fileName: 'voice.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: await file.length(),
        durationMs: duration.inMilliseconds,
      );
      widget.onSend(media);
      widget.onClose();
    } catch (_) {
      _fail(l10n.chatVoiceFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final recording = _startedAt != null;
    return Row(children: [
      IconButton(
        tooltip: l10n.chatVoiceCancel,
        icon: Icon(Icons.delete_outline_rounded, color: cs.error),
        onPressed: _discard,
      ),
      Expanded(
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            FadeTransition(
              opacity: _pulse,
              child: Container(width: 10, height: 10, decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.chatVoiceRecording,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                formatDuration(_elapsed.inMilliseconds),
                style: tt.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: l10n.chatVoiceSend,
        color: cs.primary,
        onPressed: recording ? _send : null,
        icon: const Icon(Icons.send_rounded),
      ),
    ]);
  }
}

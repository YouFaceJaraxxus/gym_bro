import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/media_upload.dart';
import '../../services/settings_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import 'body_metric_labels.dart';

/// Photos larger than this are refused before uploading (the API takes 20 MB).
const kMaxProgressPhotoBytes = 20 * 1024 * 1024;

/// Camera or gallery → pose, date (and optional weight) → upload. Returns
/// the new photo, or null when cancelled.
Future<ProgressPhoto?> addProgressPhotoFlow(BuildContext context, {ProgressPose? pose}) async {
  final l10n = context.l10n;
  final source = await showAppBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.bodyPhotoTake),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.bodyPhotoFromGallery),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
  if (source == null) return null;
  final x = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 2048,
    preferredCameraDevice: CameraDevice.rear,
  );
  if (x == null || !context.mounted) return null;
  final media = await PickedMedia.fromPath(x.path, name: x.name);
  if (!context.mounted) return null;
  if (media.sizeBytes > kMaxProgressPhotoBytes) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bodyPhotoTooLarge)));
    return null;
  }
  return showAppBottomSheet<ProgressPhoto>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AddProgressPhotoSheet(media: media, initialPose: pose),
  );
}

class AddProgressPhotoSheet extends StatefulWidget {
  final PickedMedia media;
  final ProgressPose? initialPose;

  const AddProgressPhotoSheet({super.key, required this.media, this.initialPose});

  @override
  State<AddProgressPhotoSheet> createState() => _AddProgressPhotoSheetState();
}

class _AddProgressPhotoSheetState extends State<AddProgressPhotoSheet> {
  final _settings = SettingsService.instance;
  final _weight = TextEditingController();
  final _note = TextEditingController();
  late ProgressPose _pose = widget.initialPose ?? ProgressPose.front;
  late DateTime _date;
  bool _saving = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 10), lastDate: now);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final wText = _weight.text.trim().replaceAll(',', '.');
    final w = wText.isEmpty ? null : double.tryParse(wText);
    if (wText.isNotEmpty && (w == null || w <= 0)) {
      setState(() => _error = l10n.trainingMeasureInvalidNumbers);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _progress = 0;
    });
    try {
      final api = ApiService();
      final token = await AuthManager.instance.getValidToken();
      final slot = await api.requestProgressPhotoUpload(
        token,
        mimeType: widget.media.mimeType,
        sizeBytes: widget.media.sizeBytes,
        fileName: widget.media.fileName,
      );
      await uploadFileToSlot(slot, widget.media, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      final photo = await api.createProgressPhoto(
        token,
        path: slot.path,
        pose: _pose,
        takenOn: _date,
        weightKg: w == null ? null : double.parse(_settings.fromDisplayWeight(w).toStringAsFixed(2)),
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, photo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat.yMMMEd(locale).format(_date);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.bodyPhotoAddTitle, style: text.titleLarge),
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.file(widget.media.file, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ProgressPose>(
              showSelectedIcon: false,
              segments: [
                for (final p in ProgressPose.values) ButtonSegment(value: p, label: Text(progressPoseLabel(p, l10n))),
              ],
              selected: {_pose},
              onSelectionChanged: _saving ? null : (s) => setState(() => _pose = s.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(dateText, semanticsLabel: l10n.trainingMeasureDateLabel(dateText)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.bodyPhotoWeightOptional,
                helperText: l10n.bodyPhotoWeightHelp,
                suffixText: _settings.weightUnit.value,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              enabled: !_saving,
              maxLength: 500,
              decoration: InputDecoration(labelText: l10n.trainingMeasureNoteOptional, counterText: ''),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l10n.bodyPhotosPrivate, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 16),
            if (_saving) ...[
              LinearProgressIndicator(value: _progress > 0 && _progress < 1 ? _progress : null),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

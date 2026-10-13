import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Opens a camera/gallery picker, uploads the chosen image via the `uploads`
/// edge function, and reports progress/result through the callbacks. Useful
/// for wiring an upload action into custom UI (e.g. an icon button inside a
/// list row) without using the [AvatarPicker]/[ImagePickerField] widgets.
Future<void> pickAndUploadImage({
  required BuildContext context,
  required String bucket,
  String? folder,
  required void Function(String url) onUploaded,
  required void Function(bool uploading) onUploadingChanged,
}) => _ImagePickerButton.pick(
  context: context,
  bucket: bucket,
  folder: folder,
  onUploaded: onUploaded,
  onUploadingChanged: onUploadingChanged,
);

/// Shared picker for uploading an image via the `uploads` edge function.
/// Handles picking (camera/gallery), uploading, loading state, and errors.
/// Calls [onUploaded] with the resulting public URL on success.
class _ImagePickerButton {
  static Future<void> pick({
    required BuildContext context,
    required String bucket,
    String? folder,
    required void Function(String url) onUploaded,
    required void Function(bool uploading) onUploadingChanged,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.l10n.shellImageChooseFromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.l10n.shellImageTakePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    onUploadingChanged(true);
    try {
      final bytes = await picked.readAsBytes();
      final token = await AuthManager.instance.getValidToken();
      final url = await ApiService().uploadImage(
        token,
        bytes: bytes,
        filename: picked.name,
        bucket: bucket,
        folder: folder,
      );
      onUploaded(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shellImageUploadFailed(
                e.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          ),
        );
      }
    } finally {
      onUploadingChanged(false);
    }
  }
}

/// Circular avatar picker (for user profile pictures).
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.imageUrl,
    required this.onUploaded,
    this.radius = 48,
    this.folder,
  });

  final String? imageUrl;
  final String? folder;
  final double radius;
  final void Function(String url) onUploaded;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      enabled: !_uploading,
      label: _uploading
          ? l10n.shellImageUploading
          : widget.imageUrl == null
          ? l10n.shellAvatarAdd
          : l10n.shellAvatarChange,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _uploading
            ? null
            : () => _ImagePickerButton.pick(
                context: context,
                bucket: 'avatars',
                folder: widget.folder,
                onUploaded: widget.onUploaded,
                onUploadingChanged: (v) => setState(() => _uploading = v),
              ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: cs.primaryContainer,
              backgroundImage: widget.imageUrl != null
                  ? NetworkImage(widget.imageUrl!)
                  : null,
              child: widget.imageUrl == null
                  ? Icon(
                      Icons.person,
                      size: widget.radius,
                      color: cs.onPrimaryContainer,
                    )
                  : null,
            ),
            if (_uploading)
              // Dark scrim over the photo; white reads on it in both themes.
              CircleAvatar(
                radius: widget.radius,
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: const CircularProgressIndicator(color: Colors.white),
              )
            else
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Icon(Icons.camera_alt, size: 16, color: cs.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rectangular content-image picker (for exercises, recipes, businesses,
/// shop items, posts).
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.imageUrl,
    required this.onUploaded,
    this.folder,
    this.height = 160,
    this.label,
  });

  final String? imageUrl;
  final String? folder;
  final double height;

  /// Placeholder text when there's no image; defaults to "Add photo".
  final String? label;
  final void Function(String url) onUploaded;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final label = widget.label ?? l10n.shellImageAddPhoto;
    return Semantics(
      button: true,
      enabled: !_uploading,
      label: _uploading
          ? l10n.shellImageUploading
          : widget.imageUrl == null
          ? label
          : l10n.shellImageChange,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _uploading
            ? null
            : () => _ImagePickerButton.pick(
                context: context,
                bucket: 'media',
                folder: widget.folder,
                onUploaded: widget.onUploaded,
                onUploadingChanged: (v) => setState(() => _uploading = v),
              ),
        child: Container(
          height: widget.height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: _uploading
              ? const Center(child: CircularProgressIndicator())
              : widget.imageUrl != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(widget.imageUrl!, fit: BoxFit.cover),
                    // Dark scrim badge over the photo; white icon on top.
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

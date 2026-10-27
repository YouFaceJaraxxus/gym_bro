import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../models/chat.dart';

/// A local file picked for sending (camera, gallery or file picker).
class PickedMedia {
  final File file;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  const PickedMedia({
    required this.file,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
  });

  AttachmentType get type => AttachmentType.fromMime(mimeType);

  /// Reads size and MIME type (from the name, then the first bytes).
  static Future<PickedMedia> fromPath(String path, {String? name, int? width, int? height, int? durationMs}) async {
    final file = File(path);
    final fileName = name ?? path.split(Platform.pathSeparator).last;
    final header = await file.openRead(0, 16).fold<List<int>>([], (a, b) => a..addAll(b));
    final mime = lookupMimeType(fileName, headerBytes: header) ?? 'application/octet-stream';
    return PickedMedia(
      file: file,
      fileName: fileName,
      mimeType: mime,
      sizeBytes: await file.length(),
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  OutgoingAttachment attachment(String path) => OutgoingAttachment(
    path: path,
    fileName: fileName,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    durationMs: durationMs,
  );
}

/// Streams a file straight to Storage through a signed upload URL, reporting
/// progress (0…1). No timeout: videos can take a while on mobile data.
Future<void> uploadFileToSlot(UploadSlot slot, PickedMedia media, {void Function(double progress)? onProgress}) async {
  final client = http.Client();
  try {
    final request = http.StreamedRequest('PUT', Uri.parse(slot.uploadUrl))
      ..headers['Content-Type'] = media.mimeType
      ..headers['x-upsert'] = 'false'
      ..contentLength = media.sizeBytes;
    var sent = 0;
    final pipe = media.file.openRead().listen(
      (chunk) {
        sent += chunk.length;
        request.sink.add(chunk);
        onProgress?.call(media.sizeBytes == 0 ? 1 : sent / media.sizeBytes);
      },
      onDone: () => request.sink.close(),
      onError: (Object e) {
        request.sink.addError(e);
        request.sink.close();
      },
      cancelOnError: true,
    );
    final response = await client.send(request);
    await pipe.cancel();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 400) {
      throw Exception('Upload failed (${response.statusCode}): $body');
    }
  } finally {
    client.close();
  }
}

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Manages picking, compressing, storing and deleting local images.
/// All images are saved under appDocDir/images/.
class ImageService {
  ImageService();

  final _picker = ImagePicker();
  static const _uuid = Uuid();

  // ── Pick ──────────────────────────────────────────────────────────────────

  /// Open the image picker (gallery or camera) and return a saved local path,
  /// or null if the user cancelled.
  Future<String?> pick({ImageSource source = ImageSource.gallery}) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (xFile == null) return null;
    return _compressAndSave(xFile.path);
  }

  // ── Compress & save ───────────────────────────────────────────────────────

  /// Compress [sourcePath] and write the result to the images directory.
  /// Returns the destination path.
  Future<String> _compressAndSave(String sourcePath) async {
    final dir = await _imagesDir();
    final destName = '${_uuid.v4()}.jpg';
    final destPath = p.join(dir.path, destName);

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      destPath,
      quality: 80,
      minWidth: 1024,
      minHeight: 1024,
      format: CompressFormat.jpeg,
    );
    // If compression failed, fall back to a plain copy.
    if (result == null) {
      await File(sourcePath).copy(destPath);
    }
    return destPath;
  }

  // ── Save raw bytes ────────────────────────────────────────────────────────

  /// Save raw bytes (e.g. from a backup restore) as a local image file.
  Future<String> saveBytes(List<int> bytes, {String? name}) async {
    final dir = await _imagesDir();
    final fileName = name ?? '${_uuid.v4()}.jpg';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Delete the image at [localPath]. Silently ignores missing files.
  Future<void> delete(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }

  // ── List ──────────────────────────────────────────────────────────────────

  /// Returns all image paths currently stored in the images directory.
  Future<List<String>> listAll() async {
    final dir = await _imagesDir();
    final entities = await dir.list().toList();
    return entities
        .whereType<File>()
        .map((f) => f.path)
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final imageServiceProvider = Provider<ImageService>((_) => ImageService());

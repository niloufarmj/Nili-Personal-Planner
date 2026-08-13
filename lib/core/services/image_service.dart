import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show AssetImage, FileImage, ImageProvider, MemoryImage, NetworkImage;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Prefix marking an image stored inline as base64 (used on web, where
/// there's no writable filesystem to save picked images to as files).
const _dataUriPrefix = 'data:image';

/// Prefix for bundled Flutter asset images.
const _assetPrefix = 'asset://';

/// Whether [path] refers to an image that can actually be rendered on this
/// platform. Native file paths only resolve to real files off web.
bool hasDisplayableImage(String? path) {
  if (path == null || path.isEmpty) return false;
  if (path.startsWith(_dataUriPrefix)) return true;
  if (path.startsWith(_assetPrefix)) return true;
  if (path.startsWith('http://') || path.startsWith('https://')) return true;
  if (kIsWeb) return false;
  return File(path).existsSync();
}

/// Returns a guaranteed displayable header cover image path for a collection.
/// Uses custom assigned cover image if present, or falls back to category pattern asset.
String getCoverImageForCollection({
  required String collectionName,
  required String template,
  String? coverImage,
}) {
  if (hasDisplayableImage(coverImage)) {
    return coverImage!;
  }
  final name = collectionName.toLowerCase();
  if (template == 'groceries' ||
      name.contains('groc') ||
      name.contains('food') ||
      name.contains('خرید خونه')) {
    return 'asset://assets/images/headers/header_house.jpg';
  }
  if (name.contains('groc') || name.contains('food') || name.contains('خرید')) {
    return 'asset://assets/images/headers/header_groceries.jpg';
  }
  if (template == 'shopping' || name.contains('shop') || name.contains('wish')) {
    return 'asset://assets/images/headers/header_shopping.jpg';
  }
  if (template == 'job' || name.contains('job') || name.contains('work')) {
    return 'asset://assets/images/headers/header_job.jpg';
  }
  if (template == 'chore' || name.contains('chore') || name.contains('clean')) {
    return 'asset://assets/images/headers/header_chores.jpg';
  }
  if (template == 'media' || name.contains('movie') || name.contains('film') || name.contains('show')) {
    return 'asset://assets/images/headers/header_movies.jpg';
  }
  if (name.contains('book') || name.contains('read') || name.contains('کتاب')) {
    return 'asset://assets/images/headers/header_books.jpg';
  }
  if (template == 'growth' ||
      template == 'upgrade' ||
      name.contains('growth') ||
      name.contains('hobby') ||
      name.contains('uni')) {
    return 'asset://assets/images/headers/header_hobbies.jpg';
  }
  return 'asset://assets/images/headers/header_projects.jpg';
}

/// Builds an [ImageProvider] for a path returned by [ImageService.pick] /
/// [ImageService.saveBytes], or null if it can't be displayed here.
ImageProvider? imageProviderFor(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith(_dataUriPrefix)) {
    return MemoryImage(base64Decode(path.substring(path.indexOf(',') + 1)));
  }
  if (path.startsWith(_assetPrefix)) {
    return AssetImage(path.substring(_assetPrefix.length));
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (kIsWeb) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return FileImage(file);
}

/// Manages picking, compressing, storing and deleting local images.
/// On native platforms, images are saved under appDocDir/images/. On web,
/// where there's no writable filesystem, they're kept inline as base64
/// data URIs and stored directly in the database column.
class ImageService {
  ImageService();

  final _picker = ImagePicker();
  static const _uuid = Uuid();

  // ── Pick ──────────────────────────────────────────────────────────────────

  /// Open the image picker (gallery or camera) and return a saved local path
  /// (or, on web, a data URI), or null if the user cancelled.
  Future<String?> pick({ImageSource source = ImageSource.gallery}) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (xFile == null) return null;
    if (kIsWeb) {
      final bytes = await xFile.readAsBytes();
      return '$_dataUriPrefix/jpeg;base64,${base64Encode(bytes)}';
    }
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
    if (kIsWeb) {
      return '$_dataUriPrefix/jpeg;base64,${base64Encode(bytes)}';
    }
    final dir = await _imagesDir();
    final fileName = name ?? '${_uuid.v4()}.jpg';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Delete the image at [localPath]. Silently ignores missing files.
  Future<void> delete(String localPath) async {
    if (kIsWeb || localPath.startsWith(_dataUriPrefix)) return;
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }

  // ── List ──────────────────────────────────────────────────────────────────

  /// Returns all image paths currently stored in the images directory.
  Future<List<String>> listAll() async {
    if (kIsWeb) return [];
    final dir = await _imagesDir();
    final entities = await dir.list().toList();
    return entities.whereType<File>().map((f) => f.path).toList();
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

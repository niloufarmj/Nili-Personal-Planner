import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';

/// Export / import a full backup zip containing the SQLite DB + images.
///
/// Zip layout:
///   manifest.json   — app version, export timestamp, file list
///   planner.db      — copy of the SQLite database
///   images/         — all user images
class BackupService {
  final AppDatabase _db;
  BackupService(this._db);

  static const _lastBackupKey = 'last_backup_epoch_ms';
  // 30 days in milliseconds
  static const _nudgeInterval = Duration(days: 30);

  // ── Export ────────────────────────────────────────────────────────────────

  /// Creates a zip backup and shares it via the OS share sheet.
  /// Returns the path of the created zip.
  Future<String> exportAndShare() async {
    final zipPath = await _buildZip();
    await Share.shareXFiles([XFile(zipPath)], text: 'Personal Planner backup');
    await _recordBackupTime();
    return zipPath;
  }

  /// Creates a zip backup and returns its path without sharing.
  Future<String> exportToFile() async {
    final path = await _buildZip();
    await _recordBackupTime();
    return path;
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Opens a file picker for the user to choose a .zip backup,
  /// then restores DB + images. Returns true on success.
  Future<bool> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return false;
    return _restoreZip(result.files.single.path!);
  }

  /// Restore directly from a known zip path.
  Future<bool> restoreFromPath(String zipPath) => _restoreZip(zipPath);

  // ── 30-day nudge ──────────────────────────────────────────────────────────

  /// Returns true if the user hasn't backed up in 30 days (or never).
  Future<bool> shouldNudge() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastBackupKey);
    if (last == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed > _nudgeInterval.inMilliseconds;
  }

  Future<DateTime?> lastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastBackupKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<String> _buildZip() async {
    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(tmpDir.path, 'planner_backup_$ts.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // DB file
    final dbPath = await _dbFilePath();
    if (await File(dbPath).exists()) {
      encoder.addFile(File(dbPath), 'app.db');
    }

    // Images directory
    final imagesDir = await _imagesDir();
    if (await imagesDir.exists()) {
      await for (final entity in imagesDir.list()) {
        if (entity is File) {
          encoder.addFile(entity, 'images/${p.basename(entity.path)}');
        }
      }
    }

    // Manifest
    final manifest = jsonEncode({
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'db': 'app.db',
    });
    final manifestBytes = utf8.encode(manifest);
    encoder.addArchiveFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    encoder.close();
    return zipPath;
  }

  Future<bool> _restoreZip(String zipPath) async {
    try {
      await _db.close();
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dbPath = await _dbFilePath();
      final imagesDir = await _imagesDir();
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      for (final file in archive) {
        if (!file.isFile) continue;
        final data = file.content as List<int>;
        if (file.name == 'app.db') {
          await File(dbPath).writeAsBytes(data);
        } else if (file.name.startsWith('images/')) {
          final imgName = p.basename(file.name);
          await File(p.join(imagesDir.path, imgName)).writeAsBytes(data);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _dbFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'app.db');
  }

  Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'images'));
  }

  Future<void> _recordBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
  }
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);

final lastBackupTimeProvider = FutureProvider.autoDispose<DateTime?>((ref) {
  return ref.watch(backupServiceProvider).lastBackupTime();
});

final shouldNudgeProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(backupServiceProvider).shouldNudge();
});

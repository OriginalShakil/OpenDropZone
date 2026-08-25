import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileItem {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime addedAt;
  final bool isDirectory;

  FileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.addedAt,
    required this.isDirectory,
  });

  factory FileItem.fromPath(String filePath) {
    final fileName = p.basename(filePath);
    int size = 0;
    bool isDir = false;

    try {
      final type = FileSystemEntity.typeSync(filePath);
      if (type == FileSystemEntityType.directory) {
        isDir = true;
      } else if (type == FileSystemEntityType.file) {
        size = File(filePath).lengthSync();
      }
    } catch (_) {
      // Best-effort in sandboxed or permission-limited environments
    }

    return FileItem(
      path: filePath,
      name: fileName.isEmpty ? filePath : fileName,
      sizeBytes: size,
      addedAt: DateTime.now(),
      isDirectory: isDir,
    );
  }

  bool get exists {
    try {
      final type = FileSystemEntity.typeSync(path);
      return type != FileSystemEntityType.notFound;
    } catch (_) {
      return false;
    }
  }

  String get extension => p.extension(path).toLowerCase();

  String get formattedSize {
    if (isDirectory) return 'Folder';
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData get icon {
    if (isDirectory) return Icons.folder_rounded;

    final ext = extension;
    if (const ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.heic', '.bmp'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (const ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'].contains(ext)) {
      return Icons.movie_rounded;
    }
    if (const ['.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg'].contains(ext)) {
      return Icons.audiotrack_rounded;
    }
    if (const ['.pdf'].contains(ext)) {
      return Icons.picture_as_pdf_rounded;
    }
    if (const ['.zip', '.tar', '.gz', '.rar', '.7z', '.dmg', '.pkg'].contains(ext)) {
      return Icons.archive_rounded;
    }
    if (const ['.dart', '.js', '.ts', '.py', '.swift', '.json', '.html', '.css', '.yaml', '.xml', '.c', '.cpp', '.rs', '.go'].contains(ext)) {
      return Icons.code_rounded;
    }
    if (const ['.doc', '.docx', '.txt', '.md', '.rtf', '.pages', '.csv', '.xlsx', '.pptx'].contains(ext)) {
      return Icons.description_rounded;
    }

    return Icons.insert_drive_file_rounded;
  }

  Color get iconColor {
    if (isDirectory) return const Color(0xFF4A90E2);

    final ext = extension;
    if (const ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.heic', '.bmp'].contains(ext)) {
      return const Color(0xFF9B51E0);
    }
    if (const ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'].contains(ext)) {
      return const Color(0xFFFF5252);
    }
    if (const ['.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg'].contains(ext)) {
      return const Color(0xFFF2994A);
    }
    if (const ['.pdf'].contains(ext)) {
      return const Color(0xFFEB5757);
    }
    if (const ['.zip', '.tar', '.gz', '.rar', '.7z', '.dmg', '.pkg'].contains(ext)) {
      return const Color(0xFF27AE60);
    }
    if (const ['.dart', '.js', '.ts', '.py', '.swift', '.json', '.html', '.css', '.yaml', '.xml', '.c', '.cpp', '.rs', '.go'].contains(ext)) {
      return const Color(0xFF2D9CDB);
    }
    if (const ['.doc', '.docx', '.txt', '.md', '.rtf', '.pages', '.csv', '.xlsx', '.pptx'].contains(ext)) {
      return const Color(0xFF219653);
    }

    return const Color(0xFF828282);
  }
}

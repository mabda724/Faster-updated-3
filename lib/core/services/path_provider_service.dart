import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class PathProviderService {
  static Future<Directory> get cacheDir async {
    if (kIsWeb) {
      return Directory('web_cache');
    }
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/faster_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  static Future<Directory> get documentsDir async {
    if (kIsWeb) {
      return Directory('web_docs');
    }
    return await getApplicationDocumentsDirectory();
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;

Future<File?> findManifest() async {
  var search = Directory.current;
  while (search.parent.path != search.path) {
    search = search.parent;
    final manifest = File(p.join(search.path, '.dartpackages'));
    if (await manifest.exists()) return manifest;
  }
  return null;
}

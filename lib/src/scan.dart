import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stream_transform/stream_transform.dart';
import 'package:yaml/yaml.dart';

/// Scans for packages under `cwd` and writes their absolute paths to a
/// `.dartpackages` file.
Future<void> scanForPackages() async {
  final manifest = File('.dartpackages').openWrite();
  await for (var package in _findPackages(Directory.current)) {
    manifest.writeln('${package.name}:${package.dir.path}');
  }
  await manifest.flush();
  await manifest.close();
  print('Wrote package manifest to .dartpackages');
}

Stream<_Package> _findPackages(Directory from) {
  return from.list().whereType<Directory>().concurrentAsyncExpand((dir) async* {
    if (p.basename(dir.path).startsWith('.')) return;
    final package = await _Package.check(dir);
    if (package.name != null) {
      yield package;
      return;
    }
    yield* _findPackages(dir);
  });
}

class _Package {
  final Directory dir;
  final String? name;
  _Package(this.dir, this.name);
  static Future<_Package> check(Directory dir) async {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (!await pubspec.exists()) return _Package(dir, null);
    final content = await pubspec.readAsString();
    final parsed = loadYaml(content);
    if (parsed == null) return _Package(dir, null);
    final name = parsed['name'] as String;
    return _Package(dir, name);
  }
}

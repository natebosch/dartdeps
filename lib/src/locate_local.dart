import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart' show ParsedYamlException;
import 'package:graphs/graphs.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:stream_transform/stream_transform.dart';

import 'exceptions.dart';
import 'directory_search.dart';

Future<String> locateLocal(String package, List<String> searchPaths) async =>
    '''
  $package:
    path: ${await localPath(package, searchPaths)}
''';

Future<String> localPath(String package, List<String> searchPaths) async {
  final gitRoot = findGitRoot(Directory.current);
  if (gitRoot == null && searchPaths.isEmpty) {
    throw UserFailure('No local git repo found, and no search paths provided');
  }
  final searched = <String>[];
  if (gitRoot != null) {
    final nearBy = await _findInDirectory(package, gitRoot) ??
        await _findInNeighbors(package, gitRoot);
    if (nearBy != null) return p.relative(nearBy);
    searched.add('this git repository and neighboring directories');
  }
  if (searchPaths.isNotEmpty) {
    for (final searchPath in searchPaths) {
      final search = Directory(searchPath);
      if (!search.existsSync()) continue;
      final path = await _findInDirectory(package, search);
      if (path != null) return p.relative(path);
    }
    searched.add('the provided search paths');
  }
  throw PackageNotFound(package, searched);
}

Future<String?> _findInNeighbors(String package, Directory gitRoot) async {
  final parent = gitRoot.parent;
  final exactMatch = Directory.fromUri(parent.uri.resolve(package));
  final search = exactMatch.existsSync()
      ? [exactMatch].followedBy(parent.subDirectories)
      : parent.subDirectories;
  for (final subdirectory in search) {
    if (subdirectory.path == gitRoot.path) continue;
    final found = await _findInDirectory(package, subdirectory);
    if (found != null) return found;
  }
}

Future<String?> _findInDirectory(String package, Directory directory) async {
  await for (final pubspecFile in _findPubspecs(directory.path)) {
    Pubspec pubspec;
    try {
      pubspec = Pubspec.parse(await pubspecFile.readAsString());
    } on ParsedYamlException {
      // This may be a pubspec being edited with a `name: local` which would
      // cause an exception as in invalid pubspec. Ignore it.
      return null;
    }
    if (pubspec.name == package) return pubspecFile.parent.path;
  }
}

Stream<File> _findPubspecs(String path) => crawlAsync<String, File>(
    [path],
    (path) async => Directory(path).file('pubspec.yaml'),
    (path, file) => file.existsSync()
        ? const []
        : (Directory(path).subDirectories).map((d) {
            return d.path;
          }).toList()).asyncWhere((f) => f.exists());

extension on Directory {
  Iterable<Directory> get subDirectories => listSync()
      .whereType<Directory>()
      .where((d) => !p.basename(d.path).startsWith('.'));

  File file(String name) => File.fromUri(uri.resolve(name));
}

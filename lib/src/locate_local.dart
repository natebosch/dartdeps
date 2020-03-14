import 'package:path/path.dart' as p;

import 'exceptions.dart';
import 'find_manifest.dart';

Future<String> locateLocal(String package) async => '''
  $package:
    path: ${await localPath(package)}
''';

Future<String> localPath(String package) async {
  final manifest = await findManifest();
  if (manifest == null) {
    throw UserFailure(
        'No .dartpackages manifest found above the current directory\n'
        'Run `dartdeps scan` in a parent directory of your local checkouts '
        'of Dart packages.');
  }
  final lines = await manifest.readAsLines();
  final key = '$package:';
  for (final line in lines) {
    if (line.startsWith(key)) {
      final path = line.split(':')[1];
      return p.relative(path, from: p.current);
    }
  }
  throw UserFailure('$package not found in manifest at ${manifest.path}');
}

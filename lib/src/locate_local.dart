import 'package:path/path.dart' as p;

import 'exceptions.dart';
import 'find_manifest.dart';

Future<int> locateLocal(String package) async {
  final manifest = await findManifest();
  if (manifest == null) {
    throw UserFailure(
        'No .dartpackages manifest found above the current directory');
  }
  final lines = await manifest.readAsLines();
  final key = '$package:';
  for (final line in lines) {
    if (line.startsWith(key)) {
      final path = line.split(':')[1];
      print(p.relative(path, from: p.current));
      return 0;
    }
  }
  throw UserFailure('$package not found in manifest at ${manifest.path}');
}

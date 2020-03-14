import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'locate_git.dart';
import 'locate_latest.dart';
import 'locate_local.dart';

Future<String> replaceDependency(String line, http.Client client) async {
  final parts = line.split(':');
  var package = parts[0].trim();
  if (package.startsWith('#')) package = package.substring(1);
  final dependencyType = parts[1].trim();
  if (dependencyType == 'local') {
    return await _localReplacement(package);
  }
  if (dependencyType == 'latest') {
    return await _latestReplacement(package, client);
  }
  if (dependencyType.startsWith('git')) {
    final ref =
        dependencyType.contains('@') ? dependencyType.split('@')[1] : null;
    return await _gitReplacement(package, ref);
  }
  throw UserFailure('Unsupported dependency type $dependencyType');
}

Future<String> _localReplacement(String package) async => '''
  $package:
    path: ${await locateLocal(package)}
''';

Future<String> _latestReplacement(String package, http.Client client) async =>
    '  $package: ${await locateLatest(package, client)}';

Future<String> _gitReplacement(String package, String ref) async {
  final spec = await locateGit(package, ref);
  return '$spec';
}

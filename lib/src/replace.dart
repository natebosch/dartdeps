import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'locate_latest.dart';
import 'locate_local.dart';

Future<String> replaceDependency(String line, http.Client client) async {
  final parts = line.split(':');
  var package = parts[0].trim();
  if (package.startsWith('#')) package = package.substring(1);
  final dependencyType = parts[1].trim();
  switch (dependencyType) {
    case 'local':
      return await _localReplacement(package);
    case 'latest':
      return await _latestReplacement(package, client);
    default:
      throw UserFailure('Unsupported dependency type $dependencyType');
  }
}

Future<String> _localReplacement(String package) async => '''
  $package:
    path: ${await locateLocal(package)}
''';

Future<String> _latestReplacement(String package, http.Client client) async =>
    '  $package: ${await locateLatest(package, client)}';

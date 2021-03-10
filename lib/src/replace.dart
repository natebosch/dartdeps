import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'locate_git.dart';
import 'locate_latest.dart';
import 'locate_local.dart';

Future<String> replaceDependency(
    String line, List<String> searchPaths, http.Client client) async {
  final parts = line.split(':');
  var package = parts[0].trim();
  if (package.startsWith('#')) package = package.substring(1);
  final dependencyType = parts[1].trim();
  if (dependencyType == 'local') {
    return await locateLocal(package, searchPaths);
  }
  if (dependencyType == 'latest') {
    return await locateLatest(package, client);
  }
  if (dependencyType.startsWith('git')) {
    final ref =
        dependencyType.contains('@') ? dependencyType.split('@')[1] : null;
    return '${await locateGit(package, ref)}';
  }
  throw UserFailure('Unsupported dependency type $dependencyType');
}

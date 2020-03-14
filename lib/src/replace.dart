import 'exceptions.dart';
import 'locate_local.dart';

Future<String> replaceDependency(String line) async {
  final parts = line.split(':');
  var package = parts[0].trim();
  if (package.startsWith('#')) package = package.substring(1);
  final dependencyType = parts[1].trim();
  switch (dependencyType) {
    case 'local':
      return await _localReplacement(package);
    default:
      throw UserFailure('Unsupported dependency type $dependencyType');
  }
}

Future<String> _localReplacement(String package) async => '''
  $package:
    path: ${await locateLocal(package)}
''';

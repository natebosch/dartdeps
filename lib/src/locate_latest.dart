import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import 'exceptions.dart';

final _versionQueryUri = Uri.https('pub.dev', 'api/packages/');

/// Returns a carrot constraint for the latest version of a package on pub.
///
/// Queries the pub API for the latest version of a package. Returns a carrot
/// constraint without the patch version. For example if the latest version is
/// `1.2.2` returns `^1.2.0`. For packages with a major version of `0` strips
/// the build number. For example if the latest version is `0.5.1+2` return
/// `^0.5.1`.
Future<String> locateLatest(String package, http.Client client) async {
  final decoded = await _query(package, client);
  final latest = decoded['latest'] as Map<String, dynamic>;
  final version = Version.parse(latest['version'] as String);
  final constraint = version.major == 0
      ? Version(0, version.minor, version.patch)
      : Version(version.major, version.minor, 0);
  return '  $package: ^$constraint\n';
}

Future<Map<String, dynamic>> _query(String package, http.Client client) async {
  final query = _versionQueryUri.resolve(package);
  try {
    final content = await client.read(query);
    return jsonDecode(content) as Map<String, dynamic>;
  } on http.ClientException catch (e) {
    if (e.message.contains('failed with status 404')) {
      throw UserFailure('$package not found on pub');
    }
    rethrow;
  }
}

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import 'pub_api.dart';

/// Returns a caret constraint for the latest version of a package on pub.
///
/// Queries the pub API for the latest version of a package. Returns a caret
/// constraint without the patch version. For example if the latest version is
/// `1.2.2` returns `^1.2.0`. For packages with a major version of `0` strips
/// the build number. For example if the latest version is `0.5.1+2` return
/// `^0.5.1`.
Future<String> locateLatest(String package, http.Client client) async {
  final latest = await queryPub(package, client);
  final version = Version.parse(latest['version'] as String);
  final constraint = version.major == 0
      ? Version(0, version.minor, version.patch)
      : Version(version.major, version.minor, 0);
  return '  $package: ^$constraint\n';
}

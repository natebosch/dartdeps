import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';

final _versionQueryUri = Uri.https('pub.dev', 'api/packages/');

/// Return the pub information for the latest version of [package].
Future<Map<String, dynamic>> queryPub(
    String package, http.Client client) async {
  final query = _versionQueryUri.resolve(package);
  try {
    final content = await client.read(query);
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return decoded['latest'] as Map<String, dynamic>;
  } on http.ClientException catch (e) {
    if (e.message.contains('failed with status 404')) {
      throw PackageNotPublished();
    }
    rethrow;
  }
}

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:archive/archive.dart';

import 'directory_search.dart';
import 'exceptions.dart';
import 'locate_local.dart';
import 'pub_api.dart';

class _GitSpec {
  final String package;
  final String url;
  final String? path;
  final String? ref;

  _GitSpec(
      {required this.package,
      required this.url,
      required this.path,
      required this.ref});

  @override
  String toString() {
    if (path == null && ref == null) {
      return '''
  $package:
    git: $url
''';
    } else {
      final b = StringBuffer()
        ..writeln('  $package:')
        ..writeln('    git:')
        ..writeln('      url: $url');
      if (path != null) {
        b.writeln('      path: $path');
      }
      if (ref != null) {
        b.writeln('      ref: $ref');
      }
      return '$b';
    }
  }
}

Future<String> locateGit(String package, String ref, List<String> searchPaths,
    http.Client client) async {
  try {
    return await _locateFromPubConfig(package, ref, client);
  } on PackageNotPublished {
    try {
      return await _locateFromLocalPackageCheckout(
          package, ref, searchPaths, client);
    } on PackageNotFound catch (e) {
      throw PackageNotFound(e.package, ['publisehd to pub', ...e.searched]);
    }
  }
}

Future<String> _locateFromPubConfig(
    String package, String ref, http.Client client) async {
  final latest = await queryPub(package, client);
  final pubspec = Pubspec.fromJson(latest['pubspec'] as Map<String, dynamic>);
  final repository = _findRepository(pubspec);
  final path = await _packageRelativePath(package, repository, ref);
  final spec = _GitSpec(
      package: package,
      url: Uri(
          scheme: 'git',
          host: 'github.com',
          pathSegments: [repository.org, repository.name]).toString(),
      path: path,
      ref: ref == 'master' ? null : ref);
  return '$spec';
}

_GithubRepo _findRepository(Pubspec pubspec) {
  final uri = pubspec.repository ?? pubspec.homepage?.asUri;
  if (uri == null) {
    throw UserFailure('Published package must have a repository or '
        'homepage configuration to find git URL.');
  }
  if (uri.host != 'github.com') {
    throw UserFailure('Package repository or homepage must be a github repo');
  }
  final path = uri.pathSegments.take(2).toList();
  return _GithubRepo(path[0], path[1]);
}

Future<String> _locateFromLocalPackageCheckout(String package, String ref,
    List<String> searchPaths, http.Client client) async {
  final localPackage =
      Directory(await localPath(package, searchPaths)).absolute;
  final gitRoot = findGitRoot(localPackage);
  if (gitRoot == null) {
    throw UserFailure('$package found at $localPath is not in a git repo');
  }
  final path = gitRoot.absolute.path == localPackage.path
      ? null
      : p.relative(localPackage.path, from: gitRoot.path);
  final gitUrl = await _findGitUrl(gitRoot);
  final spec = _GitSpec(
      package: package,
      url: gitUrl.toString(),
      path: path,
      ref: ref == 'master' ? null : ref);
  return '$spec';
}

Future<_GithubRepo> _findGitUrl(Directory dir) async {
  final listRemotes =
      await Process.run('git', ['remote'], workingDirectory: dir.path);
  final remoteNames =
      (listRemotes.stdout as String).split('\n').where((l) => l.isNotEmpty);
  final remoteUrls = [
    for (final remote in remoteNames) await _urlForRemote(dir, remote)
  ];
  final repos = [for (final url in remoteUrls) _GithubRepo.parse(url)!];
  for (final org in _preferredOrgs) {
    for (final repo in repos) {
      if (repo.org == org) {
        return repo;
      }
    }
  }
  throw UserFailure(
      'Cannot find a github remote in a supported org for ${dir.path}\n'
      'Available remotes: $remoteUrls\n'
      'Supported Orgs: $_preferredOrgs\n');
}

Future<String> _urlForRemote(Directory dir, String remote) async {
  final showUrl = await Process.run('git', ['remote', 'get-url', remote],
      workingDirectory: dir.path);
  return (showUrl.stdout as String).trim();
}

class _GithubRepo {
  final String org;
  final String name;
  _GithubRepo(this.org, this.name);
  static _GithubRepo? parse(String remoteUrl) {
    final path = _parseGithubPath(remoteUrl);
    if (path == null) return null;
    final parts = p.url.split(path);
    return _GithubRepo(parts[0], parts[1]);
  }

  static String? _parseGithubPath(String remoteUrl) {
    if (remoteUrl.startsWith('git@github.com:')) {
      return remoteUrl.split(':')[1];
    } else if (remoteUrl.startsWith('https://github.com/') ||
        remoteUrl.startsWith('git://github.com')) {
      return Uri.parse(remoteUrl).path;
    }
    return null;
  }
}

const _preferredOrgs = ['dart-lang', 'google'];

extension on String {
  Uri get asUri => Uri.parse(this);
}

Future<String?> _packageRelativePath(
    String package, _GithubRepo repo, String ref) async {
  final gitArchive = await http.readBytes(Uri(
      scheme: 'https',
      host: 'api.github.com',
      pathSegments: ['repos', repo.org, repo.name, 'tarball', ref]));
  final decoder = TarDecoder();
  final archive = decoder.decodeBytes(gzip.decode(gitArchive));
  final pubspecs =
      archive.where((f) => f.name.endsWith('pubspec.yaml')).toList();
  // First pass, look for package with same directory name.
  for (final file in pubspecs) {
    final parent = p.basename(p.dirname(file.name));
    if (parent != package) continue;
    if (_isPackagePubspec(package, file.read!)) {
      return _relativeArchivePath(file.name);
    }
  }
  // Second pass, check all pubspec files.
  for (final file in pubspecs) {
    if (_isPackagePubspec(package, file.read!)) {
      return _relativeArchivePath(file.name);
    }
  }
  // If it was not found, omit the path. User will need to handle it.
  return null;
}

String? _relativeArchivePath(String archiveFilePath) {
  final parts = p.split(p.dirname(archiveFilePath)).skip(1).toList();
  if (parts.isEmpty) return null;
  return p.joinAll(parts);
}

bool _isPackagePubspec(String package, String pubspecContent) =>
    Pubspec.parse(pubspecContent).name == package;

extension on ArchiveFile {
  String? get read => rawContent?.readString(size: rawContent!.length);
}

import 'dart:io';

import 'package:path/path.dart' as p;

import 'exceptions.dart';
import 'locate_local.dart';

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

Future<String> locateGit(String package, String? ref) async {
  final localPackage = Directory(await localPath(package, [])).absolute;
  final gitRoot = await _findGitRoot(localPackage);
  final path = gitRoot.absolute.path == localPackage.path
      ? null
      : p.relative(localPackage.path, from: gitRoot.path);
  final gitUrl = await _findGitUrl(gitRoot);
  final spec = _GitSpec(
      package: package,
      url: gitUrl,
      path: path,
      ref: ref == 'master' ? null : ref);
  return '$spec';
}

Future<Directory> _findGitRoot(Directory dir) async {
  if (dir.parent.path == dir.path) {
    throw UserFailure('No git repo found for ${dir.path}');
  }
  final dotGit = Directory(p.join(dir.path, '.git'));
  if (await dotGit.exists()) return dir;
  return await _findGitRoot(dir.parent);
}

Future<String> _findGitUrl(Directory dir) async {
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
      if (repo.org == org) return 'git://github.com/${repo.org}/${repo.name}';
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

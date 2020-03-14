import 'dart:io';

import 'package:path/path.dart' as p;

import 'exceptions.dart';
import 'locate_local.dart';

class GitSpec {
  final String package;
  final String url;
  final String path;
  final String ref;

  GitSpec({this.package, this.url, this.path, this.ref});

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

Future<GitSpec> locateGit(String package, String ref) async {
  final localPackage = await locateLocal(package);
  final gitRoot = await _findGitRoot(Directory(localPackage));
  final path = gitRoot.path == localPackage
      ? null
      : p.relative(localPackage, from: gitRoot.path);
  final gitUrl = await _findGitUrl(gitRoot);
  return GitSpec(package: package, url: gitUrl, path: path, ref: ref);
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
  final repos = [for (final url in remoteUrls) _GithubRepo.parse(url)];
  for (final org in _preferredOrgs) {
    for (final repo in repos) {
      if (repo.org == org) return 'git://github.com/${repo.org}/${repo.name}';
    }
  }
  throw UserFailure('Cannot find a github remote for ${dir.path}');
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
  static _GithubRepo parse(String remoteUrl) {
    final path = _parseGithubPath(remoteUrl);
    if (path == null) return null;
    final parts = p.url.split(path);
    return _GithubRepo(parts[0], parts[1]);
  }

  static String _parseGithubPath(String remoteUrl) {
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

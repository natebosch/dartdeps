import 'dart:io';

Directory? findGitRoot(Directory from) {
  for (final directory in from.absolute.parents) {
    if (directory.containsDirectoryOrFile('.git')) return directory;
  }
  return null;
}

extension on Directory {
  Iterable<Directory> get parents sync* {
    var directory = absolute;
    do {
      yield directory;
      directory = directory.parent;
    } while (directory.path != directory.parent.path);
  }

  bool containsDirectoryOrFile(String name) {
    final resolved = uri.resolve(name);
    return Directory.fromUri(resolved).existsSync() ||
        File.fromUri(resolved).existsSync();
  }
}

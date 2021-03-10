/// Exception thrown when a command fails because of some problem outside of the
/// tool.
class UserFailure implements Exception {
  final String message;
  const UserFailure(this.message);
}

class PackageNotPublished implements Exception {
  const PackageNotPublished();
}

class PackageNotFound implements UserFailure {
  final String package;
  final List<String> searched;

  @override
  String get message => '$package not found ${searched.join(', or ')}';
  const PackageNotFound(this.package, this.searched);
}

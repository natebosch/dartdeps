/// Exception thrown when a command fails because of some problem outside of the
/// tool.
class UserFailure implements Exception {
  final String message;
  const UserFailure(this.message);
}

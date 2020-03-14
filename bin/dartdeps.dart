import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartdeps/dartdeps.dart';
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:io/io.dart';

void main(List<String> args) async {
  final commandRunner = CommandRunner<int>(
      'dartdeps', 'Generate pubspec dependencies for local and git overrides.',
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : 80)
    ..addCommand(LocateGit())
    ..addCommand(LocateLatest())
    ..addCommand(LocateLocal())
    ..addCommand(Replace())
    ..addCommand(Scan());

  try {
    final parsedArgs = commandRunner.parse(args);

    final command = parsedArgs.command?.name;

    if (command == null) {
      stderr.writeln(commandRunner.usage);
      exitCode = ExitCode.usage.code;
      return;
    }

    if (command == 'help' ||
        parsedArgs.wasParsed('help') ||
        (parsedArgs.command?.wasParsed('help') ?? false)) {
      await commandRunner.runCommand(parsedArgs);
      return;
    }

    exitCode = await commandRunner.runCommand(parsedArgs);
  } on UsageException catch (e) {
    stderr..writeln(red.wrap(e.message))..writeln()..writeln(e.usage);
    exitCode = ExitCode.usage.code;
    return;
  } on UserFailure catch (e) {
    stderr.writeln(red.wrap(e.message));
    exitCode = ExitCode.config.code;
  }
}

class Scan extends Command<int> {
  @override
  String get description =>
      'Scan for local Dart projects under the current directory';

  @override
  String get name => 'scan';

  @override
  Future<int> run() async {
    print('Scanning for dart packages');
    await scanForPackages();
    return 0;
  }
}

class LocateLocal extends Command<int> {
  @override
  String get description =>
      'Prints the relative path from the current directory to the '
      'directory containing a package.';

  @override
  String get invocation => '${super.invocation} <package>';

  @override
  String get name => 'local';

  @override
  Future<int> run() async {
    if (argResults.rest.length != 1) {
      usageException('Specify a single local package to locate');
    }
    final package = argResults.rest.single;
    print(await locateLocal(package));
    return 0;
  }
}

class LocateLatest extends Command<int> {
  @override
  String get description =>
      'Prints a semver constraint for the latest feature version of a package '
      'on pub.';

  @override
  String get invocation => '${super.invocation} <package>';

  @override
  String get name => 'latest';

  @override
  Future<int> run() async {
    if (argResults.rest.length != 1) {
      usageException('Specify a single local package to locate');
    }
    final package = argResults.rest.single;
    final client = http.Client();
    try {
      print(await locateLatest(package, client));
    } finally {
      client.close();
    }
    return 0;
  }
}

class LocateGit extends Command<int> {
  @override
  String get description =>
      'Prints the git url, and optionally path and ref for a package in the '
      'dart-lang or google github org.';

  @override
  String get invocation => '${super.invocation} <package> [ref]';

  @override
  String get name => 'git';

  @override
  Future<int> run() async {
    if (argResults.rest.isEmpty || argResults.rest.length > 2) {
      usageException('Specify a single package and optionall a git ref');
    }
    final package = argResults.rest.first;
    final ref = argResults.rest.length > 1 ? argResults.rest[1] : 'master';
    final gitSpec = await locateGit(package, ref);
    print(gitSpec);
    return 0;
  }
}

class Replace extends Command<int> {
  @override
  String get description =>
      'Provides a replacement for a pubspec dependency entry from a '
      'placeholde constraint on stdin';

  @override
  String get name => 'replace';

  @override
  Future<int> run() async {
    final line = await stdin.readLineSync();
    final client = http.Client();
    try {
      print(await replaceDependency(line, client));
    } finally {
      client.close();
    }
    return 0;
  }
}

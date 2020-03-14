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
      'Scan for local Dart projects under the current directory.';

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
      'Prints a path dependency with a relative path to a local package.';

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
    stdout.write(await locateLocal(package));
    return 0;
  }
}

class LocateLatest extends Command<int> {
  @override
  String get description =>
      'Prints a semver dependency for the latest feature version of a package '
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
      stdout.write(await locateLatest(package, client));
    } finally {
      client.close();
    }
    return 0;
  }
}

class LocateGit extends Command<int> {
  @override
  String get description =>
      'Prints a git dependency for a package in the dart-lang or '
      'google github org.';

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
    stdout.write(await locateGit(package, ref));
    return 0;
  }
}

class Replace extends Command<int> {
  @override
  String get description =>
      'Prints a replacement for a pubspec dependency from a '
      'placeholder on stdin.\n\n'
      'The placeholder should be in the format `package: <style>`\n\n'
      'For example:\n'
      ' build: local\n'
      ' build: latest\n'
      ' build: git\n'
      ' build: git@ref\n';

  @override
  String get name => 'replace';

  @override
  Future<int> run() async {
    final line = await stdin.readLineSync();
    final client = http.Client();
    try {
      stdout.write(await replaceDependency(line, client));
    } finally {
      client.close();
    }
    return 0;
  }
}

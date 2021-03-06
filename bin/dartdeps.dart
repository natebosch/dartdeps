import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dartdeps/dartdeps.dart';
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final commandRunner = CommandRunner<int>(
      'dartdeps', 'Generate pubspec dependencies for packages.',
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : 80)
    ..argParser.addOption(
      'from',
      abbr: 'f',
      help: 'The path from the working directory to the `pubspec.yaml` file.',
      valueHelp: 'PATH',
    )
    ..addCommand(LocateGit())
    ..addCommand(LocateLatest())
    ..addCommand(LocateLocal())
    ..addCommand(Replace());

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
    if (parsedArgs.wasParsed('from')) {
      final from =
          p.dirname(p.relative(parsedArgs['from'] as String, from: p.current));
      final workingDirectory = Directory(from);
      if (!await workingDirectory.exists()) {
        throw UserFailure('${p.absolute(from)} is not a directory.');
      }
      if (from != p.current) Directory.current = Directory(from);
    }

    exitCode = await commandRunner.runCommand(parsedArgs) ?? 0;
  } on UsageException catch (e) {
    stderr..writeln(red.wrap(e.message))..writeln()..writeln(e.usage);
    exitCode = ExitCode.usage.code;
    return;
  } on UserFailure catch (e) {
    stderr.writeln(red.wrap(e.message));
    exitCode = ExitCode.config.code;
  }
}

class LocateLocal extends Command<int> {
  LocateLocal() {
    _addSearchPathsOption(argParser);
  }

  @override
  String get description =>
      'Prints a path dependency with a relative path to a local package.';

  @override
  String get invocation => '${super.invocation} <package>';

  @override
  String get name => 'local';

  @override
  Future<int> run() async {
    final argResults = this.argResults!;
    if (argResults.rest.length != 1) {
      usageException('Specify a single local package to locate');
    }
    final package = argResults.rest.single;
    stdout.write(
        await locateLocal(package, argResults['search-path'] as List<String>));
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
    if (argResults!.rest.length != 1) {
      usageException('Specify a single local package to locate');
    }
    final package = argResults!.rest.single;
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
  LocateGit() {
    _addSearchPathsOption(argParser);
  }
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
    final argResults = this.argResults!;
    if (argResults.rest.isEmpty || argResults.rest.length > 2) {
      usageException('Specify a single package and optionall a git ref');
    }
    final package = argResults.rest.first;
    final ref = argResults.rest.length > 1 ? argResults.rest[1] : 'master';
    final client = http.Client();
    try {
      stdout.write(await locateGit(
          package, ref, argResults['search-path'] as List<String>, client));
    } finally {
      client.close();
    }
    return 0;
  }
}

class Replace extends Command<int> {
  Replace() {
    _addSearchPathsOption(argParser);
  }
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
    final argResults = this.argResults!;
    final line = stdin.readLineSync()!;
    final client = http.Client();
    try {
      stdout.write(await replaceDependency(
          line, argResults['search-path'] as List<String>, client));
    } finally {
      client.close();
    }
    return 0;
  }
}

void _addSearchPathsOption(ArgParser argParser) {
  argParser.addMultiOption('search-path',
      abbr: 's',
      help: 'The local paths where source code is checked out.\n'
          r'For example "$HOME/source".',
      valueHelp: 'path');
}

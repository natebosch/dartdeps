import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartdeps/dartdeps.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';

void main(List<String> args) async {
  final commandRunner = CommandRunner<int>(
      'dartdeps', 'Generate pubspec dependencies for local and git overrides.')
    ..addCommand(Scan())
    ..addCommand(LocateLocal());

  try {
    final parsedArgs = commandRunner.parse(args);

    final command = parsedArgs.command?.name;

    if (command == null) {
      commandRunner.printUsage();
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
    print(red.wrap(e.message));
    print('');
    print(e.usage);
    exitCode = ExitCode.usage.code;
    return;
  } on UserFailure catch(e) {
    print(red.wrap(e.message));
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
    await locateLocal(package);
    return 0;
  }
}

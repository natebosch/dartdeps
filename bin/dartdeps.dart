import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:io/ansi.dart';

void main(List<String> args) async {
  final commandRunner = CommandRunner<int>(
      'dartdeps', 'Generate pubspec dependencies for local and git overrides.')
    ..addCommand(Scan());

  ArgResults parsedArgs;
  try {
    parsedArgs = commandRunner.parse(args);
  } on UsageException catch (e) {
    print(red.wrap(e.message));
    print('');
    print(e.usage);
    exitCode = ExitCode.usage.code;
    return;
  }

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
}

class Scan extends Command<int> {
  @override
  String get description =>
      'Scan for local Dart projects under the current directory';

  @override
  String get name => 'scan';

  @override
  Future<int> run() async {
    print('Scan for dart packages');
    return 0;
  }
}

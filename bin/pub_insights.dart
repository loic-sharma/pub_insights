import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:console_bars/console_bars.dart';
import 'package:path/path.dart' as path;
import 'package:pub_insights/output.dart';
import 'package:pub_insights/package_downloader.dart';
import 'package:pub_insights/pub_client.dart' as client;

const String _directoryFlag = 'directory';
const String _helpFlag = 'help';
const String _fetchModeFlag = 'fetch-mode';
const String _fetchModeAll = 'all';
const String _fetchModePopular = 'popular';
const String _fetchModeFile = 'file';
const String _fetchModeNone = 'none';
const String _fetchFileFlag = 'fetch-file';
const String _optimizeTablesFlag = 'optimize-tables';

Future<void> main(List<String> arguments) async {
  final ArgParser parser = ArgParser()
    ..addOption(
      _directoryFlag,
      defaultsTo: 'data',
      abbr: 'd',
      help: 'Directory to download data into',
    )
    ..addOption(
      _fetchModeFlag,
      allowed: ['all', 'popular', 'file', 'none'],
      abbr: 'm',
      help: 'What set of packages to download.',
      defaultsTo: _fetchModePopular,
    )
    ..addOption(
      _fetchFileFlag,
      abbr: 'f',
      help: 'File to use as package input. Must be set if $_fetchModeFlag is file.',
    )
    ..addFlag(
      _optimizeTablesFlag,
      abbr: 'o',
      help: 'Collapse versions and stores into respective jsonl files',
      defaultsTo: true,
    )
    ..addFlag(
      _helpFlag,
      negatable: false,
      abbr: 'h',
      help: 'Print this reference.',
    );
  final ArgResults argResults = parser.parse(arguments);

  if (argResults.flag(_helpFlag) || arguments.isEmpty) {
    print('Usage: dart run bin/pub_insights.dart [options]');
    print('');
    print(parser.usage);
    exit(0);
  }

  final String baseDir =
      path.dirname(path.dirname(Platform.script.toFilePath()));
  // Default output dir is data/
  Directory outputDir = Directory(path.canonicalize('$baseDir/data/'));
  if (argResults.option(_directoryFlag) != null) {
    outputDir =
        Directory(path.canonicalize(argResults.option(_directoryFlag)!));
  }

  if (!outputDir.existsSync()) {
    print('Can find directory $outputDir');
    exit(1);
  }

  final metadataDir = Directory(path.join(outputDir.path, 'metadata'));
  final versionsDir = Directory(path.join(outputDir.path, 'versions'));
  final packageDir = Directory(path.join(outputDir.path, 'packages'));
  final entriesDir = Directory(path.join(outputDir.path, 'entries'));
  final scoresDir = Directory(path.join(outputDir.path, 'scores'));
  final tablesDir = Directory(path.join(outputDir.path, 'tables'));

  await Future.wait([
    metadataDir.create(recursive: true),
    versionsDir.create(recursive: true),
    packageDir.create(recursive: true),
    entriesDir.create(recursive: true),
    scoresDir.create(recursive: true),
    tablesDir.create(recursive: true),
  ]);

  final packageDownloader = PackageDownloader(
    metadataDir: metadataDir,
    versionsDir: versionsDir,
    packageDir: packageDir,
    entriesDir: entriesDir,
    scoresDir: scoresDir,
    tablesDir: tablesDir,
  );

  final mode = argResults.option(_fetchModeFlag) ?? '';
  print('fetch mode "$mode"...');
  switch (mode) {
    case _fetchModeAll:
      print('Discovering all packages...');
      final packages = await client.listPackages();
      await packageDownloader.download(packages);
      break;
    case _fetchModePopular:
      print('Discovering popular packages...');
      final packages = await client.listPopularPackages();
      await packageDownloader.download(packages);
      break;
    case _fetchModeFile:
      if (!argResults.wasParsed(_fetchFileFlag)) {
        print('File flag must be set when using $_fetchModeFile');
        exit(1);
      }
      final fetchFile = argResults.option(_fetchFileFlag) as String;
      print('Discovering packages from $fetchFile...');
      final packages =
          await client.listPackagesFromFile(path.relative(fetchFile));
      await packageDownloader.download(packages);
      break;
    case _fetchModeNone:
      print('Skipping downloading...');
      break;
    default:
      print('Unknown fetch mode "$mode"');
      break;
  }

  if (argResults.flag(_optimizeTablesFlag)) {
    print('Optimizing tables...');

    final Stopwatch stopwatch = Stopwatch()..start();
    final reports = {
      'package_versions.json': versionsDir,
      'package_scores.json': scoresDir,
    };

    for (final report in reports.entries) {
      final output = report.key;
      final inputDir = report.value;

      print('Creating table $output...');
      final mergedCount = await mergeFiles(
        inputDir,
        File('${tablesDir.path}/$output'),
      );
      if (mergedCount == 0) {
        print('No files to merge.');
        exit(1);
      } else {
        print('Creating table $output done after ${duration(stopwatch)}');
        print('');
      }
      stopwatch.reset();
    }
  }
}

Future<int> mergeFiles(Directory inputDir, File output) async {
  final entities = inputDir.listSync(recursive: true);
  if (entities.isEmpty) {
    return 0;
  }
  final statusBar = FillingBar(
    desc: 'Working',
    total: entities.length,
  );

  final writer = output.openWrite();
  for (final entity in entities) {
    if (entity is File) {
      writer.add(await entity.readAsBytes());
    }
    statusBar.increment();
  }

  print('');
  await writer.flush();
  await writer.close();
  return entities.length;
}

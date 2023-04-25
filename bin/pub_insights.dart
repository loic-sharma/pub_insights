import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart' as archive;
import 'package:console_bars/console_bars.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pub_insights/isolate_worker.dart';
import 'package:pub_insights/pub_client.dart' as client;

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    print('Usage: pub_insights <output path>');
    return;
  }

  final outputDir = Directory(path.canonicalize(arguments[0]));
  final metadataDir = Directory(path.join(outputDir.path, 'metadata'));
  final packageDir = Directory(path.join(outputDir.path, 'packages'));
  final entriesDir = Directory(path.join(outputDir.path, 'entries'));
  final tablesDir = Directory(path.join(outputDir.path, 'tables'));

  await Future.wait([
    metadataDir.create(recursive: true),
    packageDir.create(recursive: true),
    entriesDir.create(recursive: true),
    tablesDir.create(recursive: true),
  ]);

  final Stopwatch stopwatch = Stopwatch()..start();

  print('Discovering packages...');
  final packages = await client.listPackages();
  print('Discovered ${packages.length} packages');
  print('');

  // Download all packages' metadata to disk.
  print('Launching metadata workers...');
  await launchWorkers(
    Queue<String>()..addAll(packages),
    createMetadataWorker(metadataDir.path),
  );

  print('Package metadata workers done after ${duration(stopwatch)}');
  print('');
  stopwatch.reset();

  // For each package version, create a list of the package ID, version, and archive URL.
  print('Finding package versions...');
  final packageVersions = await listPackageAndVersions(
    metadataDir.path,
    Queue<String>()..addAll(packages),
  );
  print('Found package version after ${duration(stopwatch)}');
  print('');
  stopwatch.reset();

  // Download all packages to disk.
  print('Launching package download workers...');

  await launchWorkers(
    Queue<List<String>>()..addAll(packageVersions),
    createDownloadWorker(metadataDir.path, packageDir.path),
  );

  print('Package download workers done after ${duration(stopwatch)}');
  print('');
  stopwatch.reset();

  // Process all package archives' entries.
  print('Launching package archive entries workers...');

  await launchWorkers(
    Queue<List<String>>()..addAll(packageVersions),
    createPackageArchiveEntriesWorker(
      metadataDir.path,
      packageDir.path,
      entriesDir.path,
    ),
  );

  print('Package archive entries workers done after ${duration(stopwatch)}');
  print('');
  stopwatch.reset();

  // Write final reports.
  print('Creating reports...');
  await mergeFiles(
    entriesDir,
    File('${tablesDir.path}/package_archive_entries.json'),
  );
  print('Creating reports done after ${duration(stopwatch)}');
  print('');
  stopwatch.reset();
}

Future<void> Function(String) createMetadataWorker(
  String metadataPath,
) {
  return (String package) async {
    try {
      final file = File('$metadataPath/$package.json');

      if (await file.exists() && await file.length() > 0) {
        return;
      }

      final data = await client.packageMetadata(package);

      await file.writeAsBytes(data, flush: true);
    } catch (e) {
      print('Failed to process $package: $e');
    }
  };
}

Future<void> Function(List<String>) createDownloadWorker(String metadataPath, String packagePath) {
  return (List<String> packageVersion) async {
    final package = packageVersion[0];
    final version = packageVersion[1];
    final archiveUrl = packageVersion[2];

    final packageIdLower = package.toLowerCase();
    final identity = '$packageIdLower/${version.toLowerCase()}';

    try {
      await Directory('$packagePath/$packageIdLower').create();

      final archiveFile = File('$packagePath/$identity.tar.gz');
      if (await archiveFile.exists() && await archiveFile.length() > 0) {
        return;
      }
      // print('Downloading $package $version from $archiveUrl...');

      final response = await http.get(Uri.parse(archiveUrl));

      await archiveFile.writeAsBytes(response.bodyBytes, flush: true);
    }
    catch (e, s) {
      print('Failed to download $package $version: $e');
      print(s);
    }
  };
}

Future<void> Function(List<String>) createPackageArchiveEntriesWorker(
  String metadataPath,
  String packagePath,
  String entriesPath,
) {
  return (List<String> packageVersion) async {
    final package = packageVersion[0];
    final version = packageVersion[1];

    final packageIdLower = package.toLowerCase();
    final identity = '$packageIdLower/${version.toLowerCase()}';

    try {
      await Directory('$entriesPath/$packageIdLower').create();

      final archiveFile = File('$packagePath/$identity.tar.gz');
      final entriesFile = File('$entriesPath/$identity.json');
      if (await entriesFile.exists() && await archiveFile.length() > 0) {
        return;
      }

      // print('Processing package archive entries for $package $version...');
      final packageStream = archive.InputFileStream(archiveFile.path);
      final packageArchive = archive.TarDecoder().decodeBytes(
        archive.GZipDecoder().decodeBuffer(packageStream)
      );
      await packageStream.close();

      final entriesWriter = entriesFile.openWrite();
      for (var i = 0; i < packageArchive.files.length; i++) {
        final file = packageArchive.files[i];
        entriesWriter.writeln(json.encode({
          'lower_id': packageIdLower,
          'identity': identity,
          'id': package,
          'version': version,
          'sequence_number': i,
          'name': file.name,
          'last_modified': file.lastModTime,
          'uncompressed_size': file.size,
        }));
      }

      await entriesWriter.flush();
      await entriesWriter.close();
    } catch (e, s) {
      print('Failed to process package archive entries for $package $version: $e');
      print(s);
    }
  };
}

Future<List<List<String>>> listPackageAndVersions(
  String metadataPath,
  Queue<String> packages,
) async {
  final result = <List<String>>[];
  Future listPackageAndVersionsWorker(int _) async {
    while (packages.isNotEmpty) {
      final package = packages.removeFirst();
      final packageIdLower = package.toLowerCase();
      try {
        final metadataFile = File('$metadataPath/$packageIdLower.json');

        final metadataString = await metadataFile.readAsString();
        final metadataJson = json.decode(metadataString) as Map<String, dynamic>;
        final versionsJson = metadataJson['versions'] as List<dynamic>;

        for (final versionJson in versionsJson) {
          final version = versionJson['version'] as String;
          final archiveUrl = versionJson['archive_url'] as String;

          result.add([package, version, archiveUrl]);
        }
      } catch (e, s) {
        print('Failed to process package $package: $e');
        print(s);
      }
    }
  }

  await Future.wait(
    List.generate(Platform.numberOfProcessors, listPackageAndVersionsWorker),
  );

  return result;
}

Future<void> mergeFiles(Directory inputDir, File output) async {
  final entities = inputDir.listSync(recursive: true);
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
}

String duration(Stopwatch stopwatch) {
  final duration = stopwatch.elapsed;
  final seconds = duration.inSeconds;
  final minutes = duration.inMinutes;
  final hours = duration.inHours;

  if (seconds <= 60) {
    return '$seconds seconds';
  } else if (minutes <= 60) {
    return '$minutes minutes';
  } else {
    return '$hours hours';
  }
}

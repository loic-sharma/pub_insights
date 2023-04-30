import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  final versionsDir = Directory(path.join(outputDir.path, 'versions'));
  final packageDir = Directory(path.join(outputDir.path, 'packages'));
  final entriesDir = Directory(path.join(outputDir.path, 'entries'));
  final tablesDir = Directory(path.join(outputDir.path, 'tables'));

  await Future.wait([
    metadataDir.create(recursive: true),
    versionsDir.create(recursive: true),
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
    createMetadataWorker(metadataDir.path, versionsDir.path),
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

  // Write final tables.
  final reports = {
    'package_versions.json': versionsDir,
    // 'package_archive_entries.json': entriesDir,
  };

  for (final report in reports.entries) {
    final output = report.key;
    final inputDir = report.value;

    print('Creating table $output...');
    await mergeFiles(
      inputDir,
      File('${tablesDir.path}/$output'),
    );
    print('Creating table done after ${duration(stopwatch)}');
    print('');
    stopwatch.reset();
  }
}

Future<void> Function(String) createMetadataWorker(
  String metadataPath,
  String versionsPath,
) {
  return (String package) async {
    try {
      Uint8List? metadata;

      // Cache the package's metadata to disk.
      final metadataFile = File('$metadataPath/$package.json');
      if (!await metadataFile.exists() || await metadataFile.length() == 0) {
        metadata = await client.packageMetadata(package);

        await metadataFile.writeAsBytes(metadata, flush: true);
      }

      // Create the package versions report.
      final versionsFile = File('$versionsPath/$package.json');
      if (!await versionsFile.exists() || await versionsFile.length() == 0) {
        // Read the metadata from disk if it was previously cached.
        metadata ??= await metadataFile.readAsBytes();

        final metadataJson = json.decode(utf8.decode(metadata)) as Map<String, dynamic>;

        final name = metadataJson['name'] as String;
        final latest = metadataJson['latest']['version'];
        final versions = metadataJson['versions'] as List<dynamic>;

        final lowerId = name.toLowerCase();

        final versionsWriter = versionsFile.openWrite();
        for (Map<String, dynamic> versionJson in versions) {
          final version = versionJson['version'] as String;
          final archiveUrl = versionJson['archive_url'] as String;
          final archiveSha256 = versionJson['archive_sha256'] as String;
          final published = versionJson['published'] as String;
          final pubspecJson = versionJson['pubspec'] as Map<String, dynamic>;

          final lowerVersion = version.toLowerCase();
          final outputJson = json.encode({
            'lower_id': lowerId,
            'identity': '$lowerId/$lowerVersion',
            'id': name,
            'version': version,
            'archive_url': archiveUrl,
            'archive_sha256': archiveSha256,
            'published': published,
            'is_latest': version == latest,
            'pubspec': json.encode(pubspecJson),
          });

          versionsWriter.writeln(outputJson);

          // final outputBytes = utf8.encode('$outputJson\n');
          // final outputGzipped = gzip.encode(outputBytes);
          // versionsWriter.add(outputGzipped);
        }

        await versionsWriter.flush();
        await versionsWriter.close();
      }
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

        final outputJson = json.encode({
          'lower_id': packageIdLower,
          'identity': identity,
          'id': package,
          'version': version,
          'sequence_number': i,
          'name': file.name,
          'last_modified': file.lastModTime,
          'uncompressed_size': file.size,
        });

        entriesWriter.writeln(outputJson);

        // final outputBytes = utf8.encode('$outputJson\n');
        // final outputGzipped = gzip.encode(outputBytes);
        // entriesWriter.add(outputGzipped);
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

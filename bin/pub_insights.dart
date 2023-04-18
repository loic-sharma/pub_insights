import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart' as archive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pub_insights/isolate_worker.dart';
import 'package:pub_insights/pub_client.dart' as client;

Future<void> main(List<String> arguments) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  final metadataDir = Directory('D:/pub/metadata');
  final packageDir = Directory('D:/pub/packages');
  final contentsDir = Directory('D:/pub/contents');

  await metadataDir.create(recursive: true);
  await packageDir.create(recursive: true);
  await contentsDir.create(recursive: true);

  print('Discovering packages...');
  final packages = await client.listPackages();
  print('Discovered ${packages.length} packages');

  // Download all packages' metadata to disk.
  print('Launching metadata workers...');
  final metadataWorkers = <Future>[];
  for (var i = 0; i < 16; i++) {
    metadataWorkers.add(metadataWorker(
      Queue<String>()..addAll(packages),
      metadataDir,
    ));
  }

  await Future.wait(metadataWorkers);
  print('Package metadata workers done after ${duration(stopwatch)}');
  stopwatch.reset();

  // Download all packages to disk.
  print('Launching package download workers...');

  await launchWorkers(
    Queue<String>()..addAll(packages),
    createDownloadWorker(metadataDir.path, packageDir.path),
  );

  print('Package download workers done after ${duration(stopwatch)}');
  stopwatch.reset();

  // Process all packages' contents.
  print('Launching package content workers...');

  await launchWorkers(
    Queue<String>()..addAll(packages),
    createPackageContentsWorker(packageDir.path, contentsDir.path),
  );

  print('Package content workers done after ${duration(stopwatch)}');
  stopwatch.reset();

  // Determine which packages contain .dll
  print('Finding packages with compiled code...');

  await launchWorkers(
    Queue<String>()..addAll(packages),
    createCompiledCodeWorker(contentsDir.path),
  );

  print('Done finding compiled code after ${duration(stopwatch)}');
  stopwatch.reset();
}

Future metadataWorker(
  Queue<String> work,
  Directory metadataDir,
) async {
  while (work.isNotEmpty) {
    final package = work.removeFirst();

    print('Processing metadata for $package, ${work.length} remaining...');
    try {
      final file = File('${metadataDir.path}/$package.json');

      // TODO: Check the file's last modified date to see if it's stale.
      if (!(await file.exists())) {
        final data = await client.packageMetadata(package);

        await file.writeAsBytes(data, flush: true);
      }
    }
    catch (e) {
      print('Failed to process $package: $e');
    }
  }
}

Future<void> Function(String) createDownloadWorker(String metadataPath, String packagePath) {
  return (String package) async {
    try {
      // Skip packages that have already been downloaded.
      final file = File('$packagePath/$package.tar.gz');
      if (await file.exists()) {
        return;
      }

      final metadataFile = File('$metadataPath/$package.json');

      final metadataString = await metadataFile.readAsString();
      final metadataJson = json.decode(metadataString) as Map<String, dynamic>;

      final Uri url = Uri.parse(metadataJson['latest']['archive_url'] as String);

      print('Downloading $package from $url...');

      final response = await http.get(url);

      await file.writeAsBytes(response.bodyBytes, flush: true);
    }
    catch (e) {
      print('Failed to download $package: $e');
    }
  };
}

Future<void> Function(String) createPackageContentsWorker(
  String packagePath,
  String packageContentsPath,
) {
  return (String package) async {
    try {
      final packageFile = File('$packagePath/$package.tar.gz');
      final contentsFile = File('$packageContentsPath/$package.json');

      if (await contentsFile.exists()) {
        return;
      }

      print('Processing contents for $package...');

      final packageStream = archive.InputFileStream(packageFile.path);
      final packageArchive = archive.TarDecoder().decodeBytes(
        archive.GZipDecoder().decodeBuffer(packageStream)
      );
      await packageStream.close();

      final contentsWriter = contentsFile.openWrite();
      for (final file in packageArchive.files) {
        contentsWriter.writeln(json.encode({
          'name': file.name,
          'size': file.size,
        }));
      }

      await contentsWriter.flush();
      await contentsWriter.close();
    } catch (e, s) {
      print('Failed to process package contents for $package: $e');
      print(s);
    }
  };
}

Future<void> Function(String) createCompiledCodeWorker(
  String packageContentsPath,
) {
  return (String package) async {
    try {
      final contentsFile = File('$packageContentsPath/$package.json');
      if (!await contentsFile.exists()) {
        print('Could not find package contents file for $package');
        return;
      }

      for (var line in await contentsFile.readAsLines()) {
        final contents = json.decode(line) as Map<String, dynamic>;
        final name = contents['name'] as String;
        final segments = path.split(path.normalize(name));

        // Ignore anything in the example directory.
        if (segments.length > 1 && segments[0] == 'example') {
          continue;
        }

        if (path.extension(name) == '.dll') {
          print(package);
          return;
          //print('$package: $name');
        }
      }
    } catch (e, s) {
      print('Failed to process package contents for $package: $e');
      print(s);
    }
  };
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

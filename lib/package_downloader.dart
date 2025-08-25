import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' as archive;
import 'package:http/http.dart' as http;
import 'package:pub_insights/isolate_worker.dart';
import 'package:pub_insights/output.dart';
import 'package:pub_insights/pub_client.dart' as client;

class PackageDownloader {
  PackageDownloader({
    required this.metadataDir,
    required this.versionsDir,
    required this.packageDir,
    required this.entriesDir,
    required this.scoresDir,
    required this.tablesDir,
    this.latestOnly = false,
  });

  final Directory metadataDir;
  final Directory versionsDir;
  final Directory packageDir;
  final Directory entriesDir;
  final Directory scoresDir;
  final Directory tablesDir;

  /// If true, only download the highest stable version of each package.
  final bool latestOnly;

  Future<void> download(List<String> packages) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    print('Discovered ${packages.length} packages');
    print('');

    // Download all packages' metadata to disk.
    print('Launching metadata workers...');
    await launchWorkers(
      Queue<String>()..addAll(packages),
      _createMetadataWorker(metadataDir.path, versionsDir.path),
    );

    print('Package metadata workers done after ${duration(stopwatch)}');
    print('');
    // Download all packages' scores to disk.
    print('Launching scores workers...');
    await launchWorkers(
      Queue<String>()..addAll(packages),
      _createScoresWorker(scoresDir.path),
    );

    print('Package scores workers done after ${duration(stopwatch)}');
    print('');
    stopwatch.reset();

    // For each package version, create a list of the package ID, version, and archive URL.
    print('Finding package versions...');
    final packageVersions = await _listPackageAndVersions(
      metadataDir.path,
      Queue<String>()..addAll(packages),
      latestOnly,
    );
    print('Found package versions after ${duration(stopwatch)}');
    print('');
    stopwatch.reset();

    // Download all packages to disk.
    print('Launching package download workers...');

    await launchWorkers(
      Queue<_PackageVersion>()..addAll(packageVersions),
      _createDownloadWorker(metadataDir.path, packageDir.path),
    );

    print('Package download workers done after ${duration(stopwatch)}');
    print('');
    stopwatch.reset();

    // Process all package archives' entries.
    print('Launching package archive entries workers...');

    await launchWorkers(
      Queue<_PackageVersion>()..addAll(packageVersions),
      _createPackageArchiveEntriesWorker(
        metadataDir.path,
        packageDir.path,
        entriesDir.path,
      ),
    );

    print('Package archive entries workers done after ${duration(stopwatch)}');
    print('');
    stopwatch.reset();
  }
}

Future<void> downloadPackages(
  List<String> packages,
  Stopwatch stopwatch, {
  required Directory metadataDir,
  required Directory versionsDir,
  required Directory packageDir,
  required Directory entriesDir,
  required Directory scoresDir,
  required Directory tablesDir,
}) async {

}

Future<void> Function(String) _createMetadataWorker(
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

        final metadataJson =
            json.decode(utf8.decode(metadata)) as Map<String, dynamic>;

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

Future<void> Function(String) _createScoresWorker(
  String scoresPath,
) {
  return (String package) async {
    try {
      Uint8List? score;

      // Cache the package's metadata to disk.
      final scoreFile = File('$scoresPath/$package.json');
      if (!await scoreFile.exists() || await scoreFile.length() == 0) {
        score = await client.packageScore(package);

        final scoreJson =
            json.decode(utf8.decode(score)) as Map<String, dynamic>;

        final outputJson = json.encode({
          'lower_id': package.toLowerCase(),
          'granted_points': scoreJson['grantedPoints'] as int,
          'max_points': scoreJson['maxPoints'] as int,
          'like_count': scoreJson['likeCount'] as int,
          'download_count_30_days': scoreJson['downloadCount30Days'] as int,
          'tags': scoreJson['tags'] as List<dynamic>,
          'last_updated': scoreJson['lastUpdated'] as String,
        });

        final scoreWriter = scoreFile.openWrite();

        scoreWriter.writeln(outputJson);

        await scoreWriter.flush();
        await scoreWriter.close();
      }
    } catch (e) {
      print('Failed to process $package: $e');
    }
  };
}

Future<void> Function(_PackageVersion) _createDownloadWorker(
  String metadataPath,
  String packagePath,
) {
  return (_PackageVersion packageVersion) async {
    final package = packageVersion.id;
    final version = packageVersion.version;
    final archiveUrl = packageVersion.archiveUrl;

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
    } catch (e, s) {
      print('Failed to download $package $version: $e');
      print(s);
    }
  };
}

Future<void> Function(_PackageVersion) _createPackageArchiveEntriesWorker(
  String metadataPath,
  String packagePath,
  String entriesPath,
) {
  return (_PackageVersion packageVersion) async {
    final package = packageVersion.id;
    final version = packageVersion.version;

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
      final packageArchive = archive.TarDecoder()
          .decodeBytes(archive.GZipDecoder().decodeBuffer(packageStream));
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
      print(
          'Failed to process package archive entries for $package $version: $e');
      print(s);
    }
  };
}


Future<List<_PackageVersion>> _listPackageAndVersions(
  String metadataPath,
  Queue<String> packages,
  bool latestOnly,
) async {
  final result = <_PackageVersion>[];
  Future listPackageAndVersionsWorker(int _) async {
    while (packages.isNotEmpty) {
      final package = packages.removeFirst();
      final packageIdLower = package.toLowerCase();
      try {
        final metadataFile = File('$metadataPath/$packageIdLower.json');

        final metadataString = await metadataFile.readAsString();
        final metadataJson =
            json.decode(metadataString) as Map<String, dynamic>;

        if (latestOnly) {
          result.add(_createPackageVersion(
            package,
            metadataJson['latest'] as Map<String, dynamic>,
          ));
        } else {
          final versionsJson = metadataJson['versions'] as List<dynamic>;
          for (final versionJson in versionsJson) {
            result.add(_createPackageVersion(
              package,
              versionJson as Map<String, dynamic>,
            ));
          }
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

typedef _PackageVersion = ({String id, String version, String archiveUrl});

_PackageVersion _createPackageVersion(
  String package,
  Map<String, dynamic> json,
) => (
  id: package,
  version: json['version'] as String,
  archiveUrl: json['archive_url'] as String,
);

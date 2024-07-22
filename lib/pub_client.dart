import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

Future<List<String>> listPackages() async {
  final url = Uri.parse('https://pub.dev/api/package-names');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw '${response.statusCode} ${response.reasonPhrase}';
  }

  final data = json.decode(response.body) as Map<String, dynamic>;
  final packages = data['packages'] as List<dynamic>;
  return packages.map((id) => id as String).toList();
}

/// Subset of packages to play with on a smaller harddrive.
Future<List<String>> listPopularPackages() async {
  return listPackagesFromFile('./sources/popular-package-names.json');
}

/// Take a json file in a format identical to the return from https://pub.dev/api/package-names.
/// returns a list of packages.
Future<List<String>> listPackagesFromFile(String filepath) async {
  final response = await File(path.absolute(filepath)).readAsString();

  final data = json.decode(response) as Map<String, dynamic>;
  final packages = data['packages'] as List<dynamic>;
  return packages.map((id) => id as String).toList();
}

Future<Uint8List> packageMetadata(String package) async {
  final url = Uri.parse('https://pub.dartlang.org/api/packages/$package');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw '${response.statusCode} ${response.reasonPhrase}';
  }

  return response.bodyBytes;
}

Future<Uint8List> packageScore(String package) async {
  final url = Uri.parse('https://pub.dartlang.org/api/packages/$package/score');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw '${response.statusCode} ${response.reasonPhrase}';
  }

  return response.bodyBytes;
}

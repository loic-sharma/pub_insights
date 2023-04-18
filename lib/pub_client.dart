import 'dart:typed_data';

import 'package:http/http.dart' as http;
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

Future<Uint8List> packageMetadata(String package) async {
  final url = Uri.parse('https://pub.dartlang.org/api/packages/$package');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw '${response.statusCode} ${response.reasonPhrase}';
  }

  return response.bodyBytes;
}

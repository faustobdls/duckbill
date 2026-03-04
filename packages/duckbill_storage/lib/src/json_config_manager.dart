import 'dart:convert';
import 'dart:io';

class JsonConfigManager {
  final File configFile;

  JsonConfigManager(String path) : configFile = File(path);

  Future<void> save(Map<String, dynamic> config) async {
    if (!await configFile.parent.exists()) {
      await configFile.parent.create(recursive: true);
    }
    final content = jsonEncode(config);
    await configFile.writeAsString(content);
  }

  Future<Map<String, dynamic>> load() async {
    if (!await configFile.exists()) return {};
    final content = await configFile.readAsString();
    if (content.trim().isEmpty) return {};
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

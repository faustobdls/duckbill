import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'version.dart';

/// Self-updater that pulls the latest release from GitHub
/// and replaces the current binary in-place.
class DuckbillUpdater {
  final String repo;
  final http.Client _client;

  DuckbillUpdater({
    this.repo = duckbillRepo,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  /// Returns the platform-arch string matching the CI artifact names.
  /// e.g. "linux-x86_64", "macos-arm64", "windows-x86_64"
  static String get platformArch {
    String os;
    if (Platform.isLinux) {
      os = 'linux';
    } else if (Platform.isMacOS) {
      os = 'macos';
    } else if (Platform.isWindows) {
      os = 'windows';
    } else {
      os = 'linux'; // fallback
    }

    // Dart exposes the architecture via Platform
    final arch = _detectArch();
    return '$os-$arch';
  }

  static String _detectArch() {
    // Platform.version contains arch info like "... on "linux_x64""
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) {
      return 'arm64';
    }
    return 'x86_64';
  }

  /// Fetches the latest release tag from GitHub API.
  /// Returns a map with `tag`, `url`, and `assets`.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    final url = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
    
    try {
      final response = await _client.get(url, headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'duckbill-cli/$duckbillVersion',
      });

      if (response.statusCode != 200) {
        print('[Updater] Falha ao checar versão: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag = data['tag_name'] as String?;
      if (latestTag == null) return null;

      final assets = (data['assets'] as List<dynamic>?)
          ?.map((a) => a as Map<String, dynamic>)
          .toList() ?? [];

      return {
        'tag': latestTag,
        'body': data['body'] ?? '',
        'assets': assets,
      };
    } catch (e) {
      print('[Updater] Erro ao conectar com GitHub: $e');
      return null;
    }
  }

  /// Compares current version with the latest release tag.
  /// Returns true if a newer version is available.
  bool isNewer(String remoteTag) {
    // Strip 'v' prefix for comparison
    final remote = remoteTag.replaceFirst('v', '');
    final current = duckbillVersion;

    final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to same length
    while (remoteParts.length < 3) remoteParts.add(0);
    while (currentParts.length < 3) currentParts.add(0);

    for (var i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false; // same version
  }

  /// Finds the right asset download URL for the current platform.
  String? findAssetUrl(List<Map<String, dynamic>> assets, String binaryType) {
    final pa = platformArch;
    final ext = Platform.isWindows ? '.zip' : '.tar.gz';
    final target = 'duckbill-$binaryType-$pa$ext';

    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name == target) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// Downloads the asset, extracts it, and replaces the running binary.
  Future<bool> downloadAndReplace(String downloadUrl) async {
    final execPath = Platform.resolvedExecutable;
    final execDir = File(execPath).parent.parent.path; // bundle/ root
    final tempDir = await Directory.systemTemp.createTemp('duckbill_update');

    try {
      print('[Updater] Baixando atualização...');
      final response = await _client.get(Uri.parse(downloadUrl));
      
      if (response.statusCode != 200) {
        print('[Updater] Falha no download: HTTP ${response.statusCode}');
        return false;
      }

      final isZip = downloadUrl.endsWith('.zip');
      final archivePath = '${tempDir.path}/update${isZip ? '.zip' : '.tar.gz'}';
      await File(archivePath).writeAsBytes(response.bodyBytes);

      print('[Updater] Extraindo...');
      
      ProcessResult result;
      if (isZip) {
        result = await Process.run('powershell', [
          'Expand-Archive', '-Path', archivePath, '-DestinationPath', tempDir.path, '-Force'
        ]);
      } else {
        result = await Process.run('tar', ['-xzf', archivePath, '-C', tempDir.path]);
      }

      if (result.exitCode != 0) {
        print('[Updater] Erro ao extrair: ${result.stderr}');
        return false;
      }

      // Copy new files over the current bundle
      print('[Updater] Substituindo binários em $execDir...');
      
      if (Platform.isWindows) {
        result = await Process.run('xcopy', [
          '${tempDir.path}\\*', '$execDir\\', '/E', '/Y', '/Q'
        ]);
      } else {
        result = await Process.run('cp', ['-rf', '${tempDir.path}/.', execDir]);
      }

      if (result.exitCode != 0) {
        print('[Updater] Erro ao copiar: ${result.stderr}');
        return false;
      }

      print('[Updater] Atualização concluída com sucesso!');
      return true;

    } catch (e) {
      print('[Updater] Erro durante atualização: $e');
      return false;
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Full update flow: check -> compare -> download -> replace.
  Future<void> run({String binaryType = 'server'}) async {
    print('[Updater] Versão atual: v$duckbillVersion');
    print('[Updater] Checando atualizações em github.com/$repo...');

    final release = await checkForUpdate();
    if (release == null) {
      print('[Updater] Não foi possível checar atualizações.');
      return;
    }

    final tag = release['tag'] as String;

    if (!isNewer(tag)) {
      print('[Updater] Você já está na versão mais recente (v$duckbillVersion).');
      return;
    }

    print('[Updater] Nova versão disponível: $tag');
    print('');

    // Print changelog snippet
    final body = release['body'] as String;
    if (body.isNotEmpty) {
      final preview = body.length > 500 ? body.substring(0, 500) + '...' : body;
      print(preview);
      print('');
    }

    final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
    final url = findAssetUrl(assets, binaryType);

    if (url == null) {
      print('[Updater] Nenhum binário encontrado para ${DuckbillUpdater.platformArch}.');
      print('[Updater] Verifique as releases em: https://github.com/$repo/releases');
      return;
    }

    print('[Updater] Plataforma: ${DuckbillUpdater.platformArch}');
    print('[Updater] Asset: $url');
    
    // Ask for confirmation
    stdout.write('[Updater] Deseja atualizar agora? (Y/n): ');
    final input = stdin.readLineSync()?.trim().toLowerCase();

    if (input != null && input != '' && input != 'y' && input != 'yes' && 
        input != 's' && input != 'sim') {
      print('[Updater] Atualização cancelada.');
      return;
    }

    final success = await downloadAndReplace(url);
    if (success) {
      print('[Updater] ✅ Duckbill atualizado para $tag! Reinicie para usar a nova versão.');
    } else {
      print('[Updater] ❌ Falha na atualização. Tente novamente ou baixe manualmente.');
    }
  }
}

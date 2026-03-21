import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks GitHub for a newer app version and shows an update dialog.
///
/// Drop a `version.json` in the repo root with fields:
/// ```json
/// {
///   "latest_version": "1.1.0",
///   "latest_build": 2,
///   "min_supported_version": "1.0.0",
///   "release_notes": "Bug fixes and new themes.",
///   "download_url": "https://github.com/EchoOfCode/PESU-ATTENDENCE/releases/latest"
/// }
/// ```
/// Bump `latest_version` / `latest_build` whenever you push a new APK.
class UpdateService {
  static const _versionUrl =
      'https://raw.githubusercontent.com/EchoOfCode/PESU-ATTENDENCE/main/version.json';

  /// Call once on app launch. Does nothing if the app is up to date.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final remote = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = remote['latest_version'] as String? ?? '0.0.0';
      final remoteBuild = remote['latest_build'] as int? ?? 0;
      final releaseNotes = remote['release_notes'] as String? ?? '';
      final downloadUrl = remote['download_url'] as String? ?? '';
      final minSupported = remote['min_supported_version'] as String? ?? '0.0.0';

      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      // No update needed.
      if (remoteBuild <= localBuild) return;

      // Is this version below the minimum supported? If so, force update.
      final forceful = _compareVersions(info.version, minSupported) < 0;

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: !forceful,
        builder: (ctx) => AlertDialog(
          title: Text(forceful ? 'Update Required' : 'Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version ($remoteVersion) is available.'),
              if (releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  releaseNotes,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            if (!forceful)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(downloadUrl);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Silently fail — network errors shouldn't block app usage.
    }
  }

  /// Simple semver comparison: returns negative if a < b, 0 if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final av = (i < aParts.length ? aParts[i] : 0) ?? 0;
      final bv = (i < bParts.length ? bParts[i] : 0) ?? 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/network_preset.dart';

class StorageService {
  static const _fileName = 'network_presets.json';

  String get _appDataDir {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return '$appData\\switch_network';
    }
    return Directory.current.path;
  }

  String get _filePath => '$_appDataDir\\$_fileName';

  Future<void> _ensureDir() async {
    final dir = Directory(_appDataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<List<NetworkPreset>> loadPresets() async {
    try {
      final file = File(_filePath);
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
      return jsonList
          .map((e) => NetworkPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Storage: error loading presets: $e');
      return [];
    }
  }

  Future<void> savePresets(List<NetworkPreset> presets) async {
    try {
      await _ensureDir();
      final file = File(_filePath);
      await file.writeAsString(
        json.encode(presets.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Storage: error saving presets: $e');
    }
  }
}

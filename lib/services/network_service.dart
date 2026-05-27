import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/network_preset.dart';

class NetworkAdapterInfo {
  final String name;
  final bool isConnected;

  NetworkAdapterInfo({required this.name, required this.isConnected});
}

class NetworkConfig {
  final String? ipAddress;
  final String? subnetMask;
  final String? defaultGateway;
  final String? primaryDns;
  final String? secondaryDns;
  final bool dhcpEnabled;

  NetworkConfig({
    this.ipAddress,
    this.subnetMask,
    this.defaultGateway,
    this.primaryDns,
    this.secondaryDns,
    this.dhcpEnabled = false,
  });

  bool get isEmpty =>
      ipAddress == null && defaultGateway == null && primaryDns == null;
}

class NetworkService {
  /// Check if the app is running with admin privileges
  static Future<bool> isAdmin() async {
    try {
      // 'net session' returns error 5 (access denied) when not admin
      final result = await Process.run('net', ['session'],
          runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// List all physical network adapters
  static Future<List<NetworkAdapterInfo>> getAdapters() async {
    try {
      final result = await Process.run(
        'netsh',
        ['interface', 'show', 'interface'],
      );
      if (result.exitCode != 0) return [];
      return _parseAdapters(result.stdout as String);
    } catch (e) {
      debugPrint('NetworkService: error getting adapters: $e');
      return [];
    }
  }

  static List<NetworkAdapterInfo> _parseAdapters(String output) {
    final lines =
        output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final adapters = <NetworkAdapterInfo>[];

    int startIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('---')) {
        startIndex = i + 1;
        break;
      }
    }
    if (startIndex == -1 || startIndex >= lines.length) return adapters;

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      // Use fixed-width parsing: Admin State(15) + State(15) + Type(18) + Name
      // Fallback: split by 2+ spaces or multiple spaces
      final parts = line.trim().split(RegExp(r'\s{2,}'));
      String name;
      bool connected;

      if (parts.length >= 4) {
        final state = parts[1].trim().toLowerCase();
        connected = state == 'connected' || state == '已连接';
        name = parts.sublist(3).join(' ').trim();
      } else {
        // fallback: whitespace split
        final words = line.trim().split(RegExp(r'\s+'));
        if (words.length < 4) continue;
        final state = words[1].toLowerCase();
        connected = state == 'connected' || state == '已连接';
        name = words.sublist(3).join(' ');
      }

      if (name.isNotEmpty) {
        adapters.add(NetworkAdapterInfo(name: name, isConnected: connected));
      }
    }
    return adapters;
  }

  /// Get current IP configuration of an adapter
  static Future<NetworkConfig> getCurrentConfig(String adapterName) async {
    try {
      final result = await Process.run(
        'netsh',
        ['interface', 'ip', 'show', 'config', 'name=$adapterName'],
      );
      if (result.exitCode != 0) return NetworkConfig();
      return _parseConfig(result.stdout as String);
    } catch (e) {
      debugPrint('NetworkService: error getting config: $e');
      return NetworkConfig();
    }
  }

  static NetworkConfig _parseConfig(String output) {
    String? ip, mask, gateway, dns1, dns2;
    bool dhcp = false;

    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // DHCP enabled (只匹配 DHCP 启用行，忽略 DNS/DHCP 等)
      if (trimmed.startsWith(RegExp(r'DHCP|DHCP\s已启用'))) {
        final val = _extractValue(trimmed) ?? '';
        if (val == 'Yes' || val == '是') dhcp = true;
      }

      // IP Address (Chinese / English)
      if (trimmed.contains(RegExp(r'IP[ 地址]|IPv4')) &&
          trimmed.contains(':')) {
        final val = _extractValue(trimmed);
        if (val != null && _isIpAddress(val)) ip = val;
      }

      // Subnet Prefix (Chinese: 子网前缀)
      if (trimmed.contains(RegExp(r'Subnet|子网|Prefix')) &&
          trimmed.contains(':')) {
        final val = _extractValue(trimmed);
        if (val != null) {
          mask = val.contains('/') ? val.split('/')[0].trim() : val;
        }
      }

      // Default Gateway (排除 Gateway Metric / 网关度量)
      if (trimmed.contains(RegExp(r'Default Gateway|默认网关')) &&
          trimmed.contains(':')) {
        final val = _extractValue(trimmed);
        if (val != null && val.isNotEmpty) gateway = val;
      }

      // DNS Servers
      if (trimmed.contains(RegExp(r'DNS', caseSensitive: false)) &&
          trimmed.contains(':')) {
        final val = _extractValue(trimmed);
        if (val != null && val.isNotEmpty && _isIpAddress(val)) {
          if (dns1 == null) {
            dns1 = val;
          } else if (dns2 == null && val != dns1) {
            dns2 = val;
          }
        }
      }
    }

    return NetworkConfig(
      ipAddress: ip,
      subnetMask: mask,
      defaultGateway: gateway,
      primaryDns: dns1,
      secondaryDns: dns2,
      dhcpEnabled: dhcp,
    );
  }

  static String? _extractValue(String line) {
    final idx = line.indexOf(':');
    if (idx == -1) return null;
    final val = line.substring(idx + 1).trim();
    return val.isEmpty || val == '.' ? null : val;
  }

  static bool _isIpAddress(String v) {
    return RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(v);
  }

  /// Apply a static IP configuration to the specified adapter
  static Future<String?> applyStaticConfig(
    String adapterName,
    NetworkPreset preset,
  ) async {
    // Set IP address, subnet mask, and default gateway
    final gateway = preset.defaultGateway.isNotEmpty
        ? preset.defaultGateway
        : 'none';
    final ipResult = await Process.run('netsh', [
      'interface',
      'ip',
      'set',
      'address',
      'name=$adapterName',
      'source=static',
      preset.ipAddress,
      preset.subnetMask,
      gateway,
      '1',
    ]);
    if (ipResult.exitCode != 0) {
      return '设置 IP 失败: ${ipResult.stderr}';
    }

    // Set primary DNS
    if (preset.primaryDns.isNotEmpty) {
      final dnsResult = await Process.run('netsh', [
        'interface',
        'ip',
        'set',
        'dns',
        'name=$adapterName',
        'source=static',
        preset.primaryDns,
        'register=primary',
      ]);
      if (dnsResult.exitCode != 0) {
        return '设置 DNS 失败: ${dnsResult.stderr}';
      }
    }

    // Add secondary DNS
    if (preset.secondaryDns.isNotEmpty) {
      // Clear secondary DNS first to avoid duplicates
      await Process.run('netsh', [
        'interface',
        'ip',
        'delete',
        'dns',
        'name=$adapterName',
        preset.secondaryDns,
      ]);
      final dns2Result = await Process.run('netsh', [
        'interface',
        'ip',
        'add',
        'dns',
        'name=$adapterName',
        preset.secondaryDns,
        'index=2',
      ]);
      if (dns2Result.exitCode != 0) {
        return '设置备用 DNS 失败: ${dns2Result.stderr}';
      }
    }

    return null; // success
  }

  /// Configure adapter to use DHCP
  static Future<String?> applyDhcpConfig(String adapterName) async {
    var result = await Process.run('netsh', [
      'interface',
      'ip',
      'set',
      'address',
      'name=$adapterName',
      'source=dhcp',
    ]);
    if (result.exitCode != 0) {
      return '设置 DHCP 失败: ${result.stderr}';
    }

    result = await Process.run('netsh', [
      'interface',
      'ip',
      'set',
      'dns',
      'name=$adapterName',
      'source=dhcp',
    ]);
    if (result.exitCode != 0) {
      return '设置 DNS 自动获取失败: ${result.stderr}';
    }

    return null;
  }

  /// Apply a preset configuration to the adapter
  static Future<String?> applyPreset(
    String adapterName,
    NetworkPreset preset,
  ) async {
    if (preset.useDhcp) {
      return applyDhcpConfig(adapterName);
    } else {
      return applyStaticConfig(adapterName, preset);
    }
  }
}

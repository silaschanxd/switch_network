import 'dart:async';
import 'package:flutter/material.dart';
import '../models/network_preset.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import 'preset_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = StorageService();

  List<NetworkAdapterInfo> _adapters = [];
  List<NetworkPreset> _presets = [];
  NetworkConfig _currentConfig = NetworkConfig();
  String? _selectedAdapter;
  bool _loadingAdapters = true;
  bool _loadingConfig = false;
  bool _applying = false;
  bool _isAdmin = false;
  String? _statusMessage;
  String? _matchedPresetId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _isAdmin = await NetworkService.isAdmin();
    _presets = await _storage.loadPresets();
    if (mounted) setState(() {});
    await _refreshAdapters();
  }

  Future<void> _refreshAdapters() async {
    setState(() => _loadingAdapters = true);
    final adapters = await NetworkService.getAdapters();
    if (!mounted) return;
    setState(() {
      _adapters = adapters;
      _loadingAdapters = false;
      if (_selectedAdapter == null ||
          !_adapters.any((a) => a.name == _selectedAdapter)) {
        final connected = adapters.where((a) => a.isConnected).toList();
        _selectedAdapter = connected.isNotEmpty
            ? connected.first.name
            : adapters.isNotEmpty
                ? adapters.first.name
                : null;
      }
    });
    if (_selectedAdapter != null) {
      _refreshCurrentConfig();
    }
  }

  Future<void> _refreshCurrentConfig() async {
    if (_selectedAdapter == null) return;
    setState(() => _loadingConfig = true);
    final config = await NetworkService.getCurrentConfig(_selectedAdapter!);
    if (!mounted) return;
    setState(() {
      _currentConfig = config;
      _loadingConfig = false;
      _matchedPresetId = _findMatchingPreset();
    });
  }

  String? _findMatchingPreset() {
    if (_currentConfig.ipAddress == null) return null;
    for (final p in _presets) {
      if (p.useDhcp && _currentConfig.dhcpEnabled) return p.id;
      if (!p.useDhcp &&
          !_currentConfig.dhcpEnabled &&
          p.ipAddress == _currentConfig.ipAddress) {
        return p.id;
      }
    }
    return null;
  }

  Future<void> _applyPreset(NetworkPreset preset) async {
    if (_selectedAdapter == null) {
      _showSnackBar('请先选择一个网络适配器');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认切换'),
        content: Text(
            '将 "${preset.name}" 应用到 "$_selectedAdapter"？\n\n${_presetDetails(preset)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _applying = true;
      _statusMessage = '正在应用 "${preset.name}"...';
    });

    final error = await NetworkService.applyPreset(_selectedAdapter!, preset);
    if (!mounted) return;

    setState(() => _applying = false);

    if (error != null) {
      setState(() => _statusMessage = error);
      _showSnackBar('❌ $error', isError: true);
    } else {
      setState(() => _statusMessage = '✅ 已切换到 "${preset.name}"');
      _showSnackBar('✅ 已成功切换到 "${preset.name}"');
      // Retry reading config until IP appears (network needs time to settle)
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        await _refreshCurrentConfig();
        if (_currentConfig.ipAddress != null) break;
      }
    }
  }

  String _presetDetails(NetworkPreset preset) {
    if (preset.useDhcp) return '模式: DHCP 自动获取';
    final buf = StringBuffer('模式: 静态 IP\n');
    buf.writeln('IP: ${preset.ipAddress}');
    buf.writeln('子网掩码: ${preset.subnetMask}');
    if (preset.defaultGateway.isNotEmpty) {
      buf.writeln('网关: ${preset.defaultGateway}');
    }
    if (preset.primaryDns.isNotEmpty) {
      buf.writeln('DNS: ${preset.primaryDns}');
      if (preset.secondaryDns.isNotEmpty) {
        buf.write('备用 DNS: ${preset.secondaryDns}');
      }
    }
    return buf.toString();
  }

  Future<void> _addPreset() async {
    final result = await Navigator.of(context).push<NetworkPreset>(
      MaterialPageRoute(builder: (_) => const PresetFormPage()),
    );
    if (result != null) {
      _presets.add(result);
      await _storage.savePresets(_presets);
      setState(() {});
    }
  }

  Future<void> _editPreset(NetworkPreset preset) async {
    final result = await Navigator.of(context).push<NetworkPreset>(
      MaterialPageRoute(builder: (_) => PresetFormPage(preset: preset)),
    );
    if (result != null) {
      final index = _presets.indexWhere((p) => p.id == preset.id);
      if (index != -1) {
        _presets[index] = result;
        await _storage.savePresets(_presets);
        setState(() {});
      }
    }
  }

  Future<void> _deletePreset(NetworkPreset preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定要删除 "${preset.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _presets.removeWhere((p) => p.id == preset.id);
      await _storage.savePresets(_presets);
      setState(() {});
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────── Build ───────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络配置切换'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAdapters,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Admin warning ---
          if (!_isAdmin)
            Container(
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('需要以管理员身份运行才能切换网络配置',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text('重启为管理员',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // --- Compact status bar ---
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_statusMessage!,
                  style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 13)),
            ),

          // --- Compact header: adapter + current config ---
          _buildCompactHeader(theme),

          // --- Main content: presets ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAdapters,
              child: _presets.isEmpty
                  ? _buildEmptyPresets(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _presets.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _presets.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: _addPreset,
                              icon: const Icon(Icons.add),
                              label: const Text('添加预设'),
                            ),
                          );
                        }
                        return _buildPresetCard(_presets[index], theme);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Compact header ───

  Widget _buildCompactHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adapter dropdown row
          if (_loadingAdapters)
            const SizedBox(
              height: 36,
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_adapters.isEmpty)
            Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                const Text('未检测到适配器',
                    style: TextStyle(fontSize: 13)),
              ],
            )
          else
            SizedBox(
              height: 36,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedAdapter,
                  hint: const Text('选择适配器', style: TextStyle(fontSize: 14)),
                  items: _adapters.map((a) {
                    return DropdownMenuItem(
                      value: a.name,
                      child: Row(
                        children: [
                          Icon(
                            a.isConnected ? Icons.link : Icons.link_off,
                            size: 16,
                            color: a.isConnected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(a.name, style: const TextStyle(fontSize: 14)),
                          if (a.isConnected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle,
                                size: 14, color: Colors.green.shade600),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedAdapter = v;
                      });
                      _refreshCurrentConfig();
                    }
                  },
                ),
              ),
            ),

          const SizedBox(height: 6),

          // Compact current config summary
          if (_loadingConfig)
            const Text('读取中...', style: TextStyle(fontSize: 12, color: Colors.grey))
          else if (_currentConfig.isEmpty)
            const Text('无法读取当前配置',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            Row(
              children: [
                if (_currentConfig.ipAddress != null)
                  _chip('IP ${_currentConfig.ipAddress}', theme),
                const SizedBox(width: 6),
                if (_currentConfig.defaultGateway != null &&
                    _currentConfig.defaultGateway!.isNotEmpty)
                  _chip('网关 ${_currentConfig.defaultGateway}', theme),
                const SizedBox(width: 6),
                if (_currentConfig.primaryDns != null)
                  _chip('DNS ${_currentConfig.primaryDns}', theme),
                const SizedBox(width: 6),
                if (_currentConfig.dhcpEnabled)
                  _chip('DHCP', theme),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }

  // ─── Preset card (compact) ───

  Widget _buildEmptyPresets(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('暂无配置预设', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('点击下方按钮添加', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addPreset,
            icon: const Icon(Icons.add),
            label: const Text('添加预设'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(NetworkPreset preset, ThemeData theme) {
    final isApplying = _applying;
    final isActive = preset.id == _matchedPresetId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      color: isActive ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: isActive ? null : () => _applyPreset(preset),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  preset.useDhcp ? Icons.wifi : Icons.settings_ethernet,
                  size: 20,
                  color: isActive
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(preset.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 14,
                              color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (preset.useDhcp)
                      Text('DHCP 自动获取',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                                text: preset.ipAddress,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            if (preset.defaultGateway.isNotEmpty)
                              TextSpan(
                                text: '  · 网关 ${preset.defaultGateway}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: '编辑',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editPreset(preset),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: '删除',
                    visualDensity: VisualDensity.compact,
                    color: theme.colorScheme.error,
                    onPressed: () => _deletePreset(preset),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    onPressed: (isApplying || isActive) ? null : () => _applyPreset(preset),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: isApplying
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            isActive ? '当前' : '切换',
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

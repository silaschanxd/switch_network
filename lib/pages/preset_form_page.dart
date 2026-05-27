import 'package:flutter/material.dart';
import '../models/network_preset.dart';

class PresetFormPage extends StatefulWidget {
  final NetworkPreset? preset;

  const PresetFormPage({super.key, this.preset});

  @override
  State<PresetFormPage> createState() => _PresetFormPageState();
}

class _PresetFormPageState extends State<PresetFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _maskCtrl;
  late final TextEditingController _gatewayCtrl;
  late final TextEditingController _dns1Ctrl;
  late final TextEditingController _dns2Ctrl;
  late bool _useDhcp;

  bool get isEditing => widget.preset != null;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _ipCtrl = TextEditingController(text: p?.ipAddress ?? '');
    _maskCtrl = TextEditingController(text: p?.subnetMask ?? '255.255.255.0');
    _gatewayCtrl = TextEditingController(text: p?.defaultGateway ?? '');
    _dns1Ctrl = TextEditingController(text: p?.primaryDns ?? '');
    _dns2Ctrl = TextEditingController(text: p?.secondaryDns ?? '');
    _useDhcp = p?.useDhcp ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _maskCtrl.dispose();
    _gatewayCtrl.dispose();
    _dns1Ctrl.dispose();
    _dns2Ctrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final preset = NetworkPreset(
      id: widget.preset?.id,
      name: _nameCtrl.text.trim(),
      ipAddress: _ipCtrl.text.trim(),
      subnetMask: _maskCtrl.text.trim(),
      defaultGateway: _gatewayCtrl.text.trim(),
      primaryDns: _dns1Ctrl.text.trim(),
      secondaryDns: _dns2Ctrl.text.trim(),
      useDhcp: _useDhcp,
    );

    Navigator.of(context).pop(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑预设' : '添加预设'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '预设名称',
                hintText: '例如：办公室、家里、公司',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),

            // DHCP toggle
            SwitchListTile(
              title: const Text('使用 DHCP 自动获取'),
              subtitle: Text(
                _useDhcp ? 'IP 和 DNS 将由路由器自动分配' : '手动指定 IP 和 DNS',
              ),
              value: _useDhcp,
              onChanged: (v) => setState(() => _useDhcp = v),
            ),

            if (!_useDhcp) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP 地址',
                  hintText: '例如: 192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _useDhcp
                    ? null
                    : (v) {
                        if (v == null || v.trim().isEmpty) return '请输入 IP 地址';
                        if (!RegExp(
                                r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')
                            .hasMatch(v.trim())) {
                          return '请输入有效的 IP 地址';
                        }
                        return null;
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maskCtrl,
                decoration: const InputDecoration(
                  labelText: '子网掩码',
                  hintText: '例如: 255.255.255.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _useDhcp
                    ? null
                    : (v) {
                        if (v == null || v.trim().isEmpty) return '请输入子网掩码';
                        return null;
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gatewayCtrl,
                decoration: const InputDecoration(
                  labelText: '默认网关',
                  hintText: '例如: 192.168.1.1',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dns1Ctrl,
                decoration: const InputDecoration(
                  labelText: '首选 DNS',
                  hintText: '例如: 8.8.8.8',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dns2Ctrl,
                decoration: const InputDecoration(
                  labelText: '备用 DNS',
                  hintText: '例如: 8.8.4.4',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

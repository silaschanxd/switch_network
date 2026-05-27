class NetworkPreset {
  final String id;
  String name;
  String ipAddress;
  String subnetMask;
  String defaultGateway;
  String primaryDns;
  String secondaryDns;
  bool useDhcp;

  NetworkPreset({
    String? id,
    required this.name,
    this.ipAddress = '',
    this.subnetMask = '255.255.255.0',
    this.defaultGateway = '',
    this.primaryDns = '',
    this.secondaryDns = '',
    this.useDhcp = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ipAddress': ipAddress,
        'subnetMask': subnetMask,
        'defaultGateway': defaultGateway,
        'primaryDns': primaryDns,
        'secondaryDns': secondaryDns,
        'useDhcp': useDhcp,
      };

  factory NetworkPreset.fromJson(Map<String, dynamic> json) => NetworkPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        ipAddress: json['ipAddress'] as String? ?? '',
        subnetMask: json['subnetMask'] as String? ?? '255.255.255.0',
        defaultGateway: json['defaultGateway'] as String? ?? '',
        primaryDns: json['primaryDns'] as String? ?? '',
        secondaryDns: json['secondaryDns'] as String? ?? '',
        useDhcp: json['useDhcp'] as bool? ?? false,
      );

  NetworkPreset copyWith({
    String? name,
    String? ipAddress,
    String? subnetMask,
    String? defaultGateway,
    String? primaryDns,
    String? secondaryDns,
    bool? useDhcp,
  }) =>
      NetworkPreset(
        id: id,
        name: name ?? this.name,
        ipAddress: ipAddress ?? this.ipAddress,
        subnetMask: subnetMask ?? this.subnetMask,
        defaultGateway: defaultGateway ?? this.defaultGateway,
        primaryDns: primaryDns ?? this.primaryDns,
        secondaryDns: secondaryDns ?? this.secondaryDns,
        useDhcp: useDhcp ?? this.useDhcp,
      );

  String get summary {
    if (useDhcp) return 'DHCP 自动获取';
    final parts = <String>[ipAddress];
    if (defaultGateway.isNotEmpty) parts.add('网关: $defaultGateway');
    return parts.join(' | ');
  }
}

/// Model for app configuration fetched from backend
/// Used to control maintenance mode, force updates, and version requirements
class AppConfig {
  final String minClientVersion;
  final bool maintenance;
  final bool forceUpdate;
  final String supportWhatsApp;
  final String? message;
  final DateTime serverTime;

  const AppConfig({
    required this.minClientVersion,
    required this.maintenance,
    required this.forceUpdate,
    required this.supportWhatsApp,
    this.message,
    required this.serverTime,
  });

  /// Parse JSON response from backend API
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      minClientVersion: json['minClientVersion'] as String? ?? '1.0.0',
      maintenance: json['maintenance'] as bool? ?? false,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      supportWhatsApp: json['supportWhatsApp'] as String? ?? '',
      message: json['message'] as String?,
      serverTime: json['serverTime'] != null
          ? DateTime.parse(json['serverTime'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minClientVersion': minClientVersion,
      'maintenance': maintenance,
      'forceUpdate': forceUpdate,
      'supportWhatsApp': supportWhatsApp,
      'message': message,
      'serverTime': serverTime.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AppConfig(minClientVersion: $minClientVersion, maintenance: $maintenance, '
        'forceUpdate: $forceUpdate, supportWhatsApp: $supportWhatsApp, '
        'message: $message, serverTime: $serverTime)';
  }
}

/// Configuration for a banking app used in top-up flow
class BankAppConfig {
  final String id;
  final String name;
  final String destinationCode;
  final String? logoUrl;
  final bool isActive;

  BankAppConfig({
    required this.id,
    required this.name,
    required this.destinationCode,
    this.logoUrl,
    this.isActive = true,
  });

  /// Create from Firestore map
  factory BankAppConfig.fromMap(Map<String, dynamic> map) {
    return BankAppConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      destinationCode: map['destinationCode'] as String,
      logoUrl: map['logoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'destinationCode': destinationCode,
      'logoUrl': logoUrl,
      'isActive': isActive,
    };
  }
}

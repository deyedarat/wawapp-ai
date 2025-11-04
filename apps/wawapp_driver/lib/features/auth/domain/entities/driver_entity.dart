enum DriverStatus { offline, online, busy }

class DriverEntity {
  final String id;
  final String phoneNumber;
  final String? name;
  final String? email;
  final DriverStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  const DriverEntity({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.email,
    this.status = DriverStatus.offline,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  DriverEntity copyWith({
    String? id,
    String? phoneNumber,
    String? name,
    String? email,
    DriverStatus? status,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
  }) {
    return DriverEntity(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
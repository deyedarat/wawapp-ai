import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/driver_entity.dart';

class DriverModel extends DriverEntity {
  const DriverModel({
    required super.id,
    required super.phoneNumber,
    super.name,
    super.email,
    super.status,
    super.latitude,
    super.longitude,
    super.lastSeen,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      id: doc.id,
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'],
      email: data['email'],
      status: _parseStatus(data['status']),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      lastSeen: data['lastSeen']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'name': name,
      'email': email,
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': lastSeen ?? DateTime.now(),
    };
  }

  static DriverStatus _parseStatus(String? status) {
    switch (status) {
      case 'online': return DriverStatus.online;
      case 'busy': return DriverStatus.busy;
      default: return DriverStatus.offline;
    }
  }
}
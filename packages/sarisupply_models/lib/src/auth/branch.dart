import 'auth_enums.dart';

final class Branch {
  Branch({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.code,
    required this.address,
    required Map<String, Object?> contactDetails,
    required Map<String, Object?> operatingHours,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
  })  : contactDetails = Map.unmodifiable(contactDetails),
        operatingHours = Map.unmodifiable(operatingHours);

  factory Branch.fromMap(Map<String, Object?> map) => Branch(
        id: map['id'] as String,
        merchantId: map['merchantId'] as String,
        name: map['name'] as String,
        code: map['code'] as String,
        address: map['address'] as String,
        contactDetails: Map<String, Object?>.from(map['contactDetails'] as Map),
        operatingHours: Map<String, Object?>.from(map['operatingHours'] as Map),
        status: BranchStatus.fromWireValue(map['status'] as String),
        createdAt: map['createdAt'] as DateTime,
        createdBy: map['createdBy'] as String,
        updatedAt: map['updatedAt'] as DateTime,
      );

  final String id;
  final String merchantId;
  final String name;
  final String code;
  final String address;
  final Map<String, Object?> contactDetails;
  final Map<String, Object?> operatingHours;
  final BranchStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'merchantId': merchantId,
        'name': name,
        'code': code,
        'address': address,
        'contactDetails': contactDetails,
        'operatingHours': operatingHours,
        'status': status.wireValue,
        'createdAt': createdAt,
        'createdBy': createdBy,
        'updatedAt': updatedAt,
      };
}

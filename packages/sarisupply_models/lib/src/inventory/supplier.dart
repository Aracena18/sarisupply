class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.address,
    required this.leadTimeDays,
    this.active = true,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final int leadTimeDays;
  final bool active;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'leadTimeDays': leadTimeDays,
        'active': active,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: map['name'] as String,
        contactPerson: map['contactPerson'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        address: map['address'] as String? ?? '',
        leadTimeDays: (map['leadTimeDays'] as num?)?.toInt() ?? 1,
        active: (map['active'] as bool?) ?? true,
      );

  Supplier copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    int? leadTimeDays,
    bool? active,
  }) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        leadTimeDays: leadTimeDays ?? this.leadTimeDays,
        active: active ?? this.active,
      );
}

enum CompanyRole {
  companyOwner('companyOwner'),
  warehouseOperations('warehouseOperations'),
  rider('rider');

  const CompanyRole(this.wireValue);
  final String wireValue;

  static CompanyRole fromWireValue(Object? value) => values.firstWhere(
        (role) => role.wireValue == value,
        orElse: () => throw FormatException('Unknown company role: $value'),
      );
}

final class CompanyScope {
  CompanyScope._(this.kind, this.warehouseIds);

  factory CompanyScope.fromMap(Object? value, CompanyRole role) {
    if (value is! Map) throw const FormatException('Invalid company scope');
    final map = Map<String, Object?>.from(value);
    if (role == CompanyRole.companyOwner) {
      if (map['kind'] != 'company' || map.containsKey('warehouseIds')) {
        throw const FormatException('Invalid owner scope');
      }
      return CompanyScope._('company', const []);
    }
    final raw = map['warehouseIds'];
    if (map['kind'] != 'warehouses' ||
        raw is! List ||
        raw.isEmpty ||
        raw.length > 100) {
      throw const FormatException('Invalid warehouse scope');
    }
    final ids = raw.cast<String>();
    if (ids.any((id) => id.isEmpty || id.contains('/')) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('Invalid warehouse scope');
    }
    return CompanyScope._('warehouses', List.unmodifiable(ids));
  }

  final String kind;
  final List<String> warehouseIds;
  bool allowsWarehouse(String id) =>
      kind == 'company' || warehouseIds.contains(id);
}

final class AuthorizationWorkspace {
  AuthorizationWorkspace({
    required this.companyId,
    required this.displayName,
    required this.role,
    required this.scope,
    required this.membershipRevision,
    required this.roleGrantRevision,
  });

  factory AuthorizationWorkspace.fromMap(Object? value) {
    if (value is! Map) throw const FormatException('Invalid workspace');
    final map = Map<String, Object?>.from(value);
    final role = CompanyRole.fromWireValue(map['role']);
    final companyId = map['companyId'];
    final name = map['displayName'];
    final membershipRevision = map['membershipRevision'];
    final roleRevision = map['roleGrantRevision'];
    if (map['kind'] != 'company' ||
        companyId is! String ||
        companyId.isEmpty ||
        name is! String ||
        name.isEmpty ||
        membershipRevision is! int ||
        membershipRevision < 1 ||
        roleRevision is! int ||
        roleRevision < 1) {
      throw const FormatException('Invalid authorization workspace');
    }
    return AuthorizationWorkspace(
      companyId: companyId,
      displayName: name,
      role: role,
      scope: CompanyScope.fromMap(map['scope'], role),
      membershipRevision: membershipRevision,
      roleGrantRevision: roleRevision,
    );
  }

  final String companyId;
  final String displayName;
  final CompanyRole role;
  final CompanyScope scope;
  final int membershipRevision;
  final int roleGrantRevision;

  Map<String, Object?> get context => {
        'kind': 'company',
        'companyId': companyId,
        'role': role.wireValue,
      };
}

final class AuthorizationWorkspacePage {
  AuthorizationWorkspacePage({
    required List<AuthorizationWorkspace> workspaces,
    required this.canAdministerPlatform,
    required this.nextCursor,
    required this.hasMore,
    required this.verifiedAt,
  }) : workspaces = List.unmodifiable(workspaces);

  factory AuthorizationWorkspacePage.fromMap(Map<String, Object?> map) {
    final raw = map['workspaces'];
    if (map['authorizationVersion'] != 1 ||
        raw is! List ||
        raw.length > 50 ||
        map['canAdministerPlatform'] is! bool ||
        map['hasMore'] is! bool ||
        map['source'] != 'server' ||
        map['verifiedAt'] is! String ||
        (map['nextCursor'] != null && map['nextCursor'] is! String) ||
        ((map['hasMore'] as bool) != (map['nextCursor'] != null))) {
      throw const FormatException('Invalid authorization workspace response');
    }
    final parsed = raw.map(AuthorizationWorkspace.fromMap).toList();
    final keys = parsed
        .map((entry) => '${entry.companyId}:${entry.role.wireValue}')
        .toSet();
    if (keys.length != parsed.length) {
      throw const FormatException('Duplicate authorization workspace');
    }
    return AuthorizationWorkspacePage(
      workspaces: parsed,
      canAdministerPlatform: map['canAdministerPlatform'] as bool,
      nextCursor: map['nextCursor'] as String?,
      hasMore: map['hasMore'] as bool,
      verifiedAt: DateTime.parse(map['verifiedAt'] as String),
    );
  }

  final List<AuthorizationWorkspace> workspaces;
  final bool canAdministerPlatform;
  final String? nextCursor;
  final bool hasMore;
  final DateTime verifiedAt;
}

final class CompanyWorkspace {
  CompanyWorkspace({
    required this.authorization,
    required this.warehouseId,
  });

  factory CompanyWorkspace.fromMap(Map<String, Object?> map) {
    final auth = AuthorizationWorkspace.fromMap({
      'kind': map['kind'],
      'companyId': map['companyId'],
      'role': map['role'],
      'displayName': map['displayName'],
      'scope': map['scope'],
      'membershipRevision': map['membershipRevision'],
      'roleGrantRevision': map['roleGrantRevision'],
    });
    if (map['authorizationVersion'] != 1 ||
        map['source'] != 'server' ||
        map['verifiedAt'] is! String) {
      throw const FormatException('Invalid verified company workspace');
    }
    final selectedWarehouse = map['warehouseId'];
    if (selectedWarehouse != null &&
        (selectedWarehouse is! String ||
            !auth.scope.allowsWarehouse(selectedWarehouse))) {
      throw const FormatException('Selected warehouse is outside scope');
    }
    DateTime.parse(map['verifiedAt'] as String);
    return CompanyWorkspace(
        authorization: auth, warehouseId: selectedWarehouse as String?);
  }

  final AuthorizationWorkspace authorization;
  final String? warehouseId;
}

final class CompanyWarehouse {
  CompanyWarehouse(
      {required this.id,
      required this.name,
      required this.code,
      required this.address});

  factory CompanyWarehouse.fromMap(Object? value) {
    if (value is! Map) throw const FormatException('Invalid warehouse');
    final map = Map<String, Object?>.from(value);
    final id = map['warehouseId'],
        name = map['name'],
        code = map['code'],
        address = map['address'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        code is! String ||
        address is! String) {
      throw const FormatException('Invalid warehouse response');
    }
    return CompanyWarehouse(id: id, name: name, code: code, address: address);
  }

  final String id;
  final String name;
  final String code;
  final String address;
}

final class CompanyInvitation {
  CompanyInvitation({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.role,
    required List<String> warehouseIds,
    required this.status,
    required this.expiresAt,
    this.email,
  }) : warehouseIds = List.unmodifiable(warehouseIds);

  factory CompanyInvitation.fromMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid company invitation');
    }
    final map = Map<String, Object?>.from(value);
    final id = map['invitationId'], companyId = map['companyId'];
    final companyName = map['companyName'] ?? 'Company';
    final rawIds = map['warehouseIds'];
    final expiresAt = map['expiresAt'];
    final status = map['status'] ?? 'pending';
    if (id is! String ||
        id.isEmpty ||
        companyId is! String ||
        companyId.isEmpty ||
        companyName is! String ||
        rawIds is! List ||
        rawIds.length > 100 ||
        status is! String ||
        !const {'pending', 'accepted', 'revoked', 'expired'}.contains(status) ||
        (expiresAt != null && expiresAt is! String)) {
      throw const FormatException('Invalid company invitation response');
    }
    final ids = rawIds.cast<String>();
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Invalid invitation scope');
    }
    final role = CompanyRole.fromWireValue(map['role']);
    if (role == CompanyRole.companyOwner) {
      throw const FormatException('Company Owner cannot be invited');
    }
    final email = map['email'];
    if (email != null && email is! String) {
      throw const FormatException('Invalid invitation email');
    }
    return CompanyInvitation(
      id: id,
      companyId: companyId,
      companyName: companyName,
      role: role,
      warehouseIds: ids,
      status: status,
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt as String),
      email: email as String?,
    );
  }

  final String id;
  final String companyId;
  final String companyName;
  final CompanyRole role;
  final List<String> warehouseIds;
  final String status;
  final DateTime? expiresAt;
  final String? email;
}

final class CompanyStaffMember {
  CompanyStaffMember(
      {required this.memberId,
      required this.email,
      required this.role,
      required this.warehouseIds});

  factory CompanyStaffMember.fromMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid company staff member');
    }
    final map = Map<String, Object?>.from(value);
    final id = map['memberId'], email = map['email'];
    if (id is! String || id.isEmpty || email is! String) {
      throw const FormatException('Invalid company staff response');
    }
    final scope = CompanyScope.fromMap(
        map['scope'], CompanyRole.fromWireValue(map['role']));
    return CompanyStaffMember(
        memberId: id,
        email: email,
        role: CompanyRole.fromWireValue(map['role']),
        warehouseIds: scope.warehouseIds);
  }

  final String memberId;
  final String email;
  final CompanyRole role;
  final List<String> warehouseIds;
}

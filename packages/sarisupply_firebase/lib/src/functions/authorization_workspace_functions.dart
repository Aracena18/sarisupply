import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

final class CompanyWarehousePage {
  CompanyWarehousePage(
      {required List<CompanyWarehouse> warehouses, required this.hasMore})
      : warehouses = List.unmodifiable(warehouses);
  final List<CompanyWarehouse> warehouses;
  final bool hasMore;
}

final class CompanyInvitationPage {
  CompanyInvitationPage(
      {required List<CompanyInvitation> invitations, required this.hasMore})
      : invitations = List.unmodifiable(invitations);
  final List<CompanyInvitation> invitations;
  final bool hasMore;
}

final class CompanyStaffPage {
  CompanyStaffPage(
      {required List<CompanyStaffMember> members, required this.hasMore})
      : members = List.unmodifiable(members);
  final List<CompanyStaffMember> members;
  final bool hasMore;
}

final class AuthorizationWorkspaceFunctions {
  AuthorizationWorkspaceFunctions({required MerchantCallableGateway gateway})
      : _gateway = gateway;

  factory AuthorizationWorkspaceFunctions.forDefaultApp() =>
      AuthorizationWorkspaceFunctions(
          gateway: HttpsMerchantGateway.forApp(Firebase.app()));

  final MerchantCallableGateway _gateway;

  Future<AuthorizationWorkspacePage> getAuthorizationWorkspaces(
      {int pageSize = 25, String? cursor}) async {
    if (pageSize < 1 || pageSize > 50) {
      throw ArgumentError.value(pageSize, 'pageSize');
    }
    final result = await _gateway.call('getAuthorizationWorkspaces', {
      'authorizationVersion': 1,
      'pageSize': pageSize,
      if (cursor != null) 'cursor': cursor,
    });
    return AuthorizationWorkspacePage.fromMap(result);
  }

  Future<CompanyWorkspace> getCompanyWorkspace(AuthorizationWorkspace workspace,
      {String? warehouseId}) async {
    final result = await _gateway.call('getCompanyWorkspace', {
      'authorizationVersion': 1,
      'context': workspace.context,
      if (warehouseId != null) 'warehouseId': warehouseId,
    });
    return CompanyWorkspace.fromMap(result);
  }

  Future<CompanyWarehousePage> listWarehouses(
      AuthorizationWorkspace workspace) async {
    final result = await _gateway.call('listCompanyWarehouses', {
      'authorizationVersion': 1,
      'context': workspace.context,
      'companyId': workspace.companyId,
      'role': workspace.role.wireValue,
    });
    final raw = result['warehouses'];
    if (result['authorizationVersion'] != 1 ||
        raw is! List ||
        raw.length > 100 ||
        result['hasMore'] is! bool) {
      throw const FormatException('Invalid company warehouse page');
    }
    return CompanyWarehousePage(
      warehouses: raw.map(CompanyWarehouse.fromMap).toList(),
      hasMore: result['hasMore'] as bool,
    );
  }

  Future<List<CompanyInvitation>> listMyInvitations() async {
    final result = await _gateway.call('listMyCompanyInvitations', const {
      'authorizationVersion': 1,
    });
    final raw = result['invitations'];
    if (result['authorizationVersion'] != 1 ||
        raw is! List ||
        raw.length > 50) {
      throw const FormatException('Invalid company invitation page');
    }
    return List.unmodifiable(raw.map(CompanyInvitation.fromMap));
  }

  Future<CompanyInvitationPage> listInvitations(String companyId) async {
    final result = await _gateway.call('listCompanyInvitations', {
      'authorizationVersion': 1,
      'context': _ownerContext(companyId),
      'companyId': companyId,
    });
    final raw = result['invitations'];
    if (result['authorizationVersion'] != 1 ||
        raw is! List ||
        raw.length > 51 ||
        result['hasMore'] is! bool) {
      throw const FormatException('Invalid company invitation page');
    }
    return CompanyInvitationPage(
      invitations: raw.map(CompanyInvitation.fromMap).toList(),
      hasMore: result['hasMore'] as bool,
    );
  }

  Future<CompanyStaffPage> listStaff(String companyId) async {
    final result = await _gateway.call('listCompanyStaff', {
      'authorizationVersion': 1,
      'context': _ownerContext(companyId),
      'companyId': companyId,
    });
    final raw = result['members'];
    if (result['authorizationVersion'] != 1 ||
        raw is! List ||
        raw.length > 50 ||
        result['hasMore'] is! bool) {
      throw const FormatException('Invalid company staff page');
    }
    return CompanyStaffPage(
      members: raw.map(CompanyStaffMember.fromMap).toList(),
      hasMore: result['hasMore'] as bool,
    );
  }

  Future<void> acceptInvitation(
      CompanyInvitation invitation, String operationId) async {
    final result = await _gateway.call('acceptCompanyInvitation', {
      'authorizationVersion': 1,
      'context': {
        'kind': 'company',
        'companyId': invitation.companyId,
        'role': invitation.role.wireValue,
      },
      'companyId': invitation.companyId,
      'invitationId': invitation.id,
      'role': invitation.role.wireValue,
      'operationId': operationId,
    });
    if (result['authorizationVersion'] != 1 ||
        result['companyId'] != invitation.companyId ||
        result['role'] != invitation.role.wireValue ||
        result['status'] != 'accepted' ||
        result['operationId'] != operationId) {
      throw const FormatException(
          'Invalid invitation acceptance acknowledgement');
    }
  }

  Future<void> createInvitation({
    required String companyId,
    required String email,
    required CompanyRole role,
    required List<String> warehouseIds,
    required String operationId,
  }) async {
    final result = await _gateway.call('createCompanyInvitation', {
      'authorizationVersion': 1,
      'context': _ownerContext(companyId),
      'companyId': companyId,
      'email': email,
      'role': role.wireValue,
      'warehouseIds': warehouseIds,
      'operationId': operationId,
    });
    if (result['authorizationVersion'] != 1 ||
        result['companyId'] != companyId ||
        result['role'] != role.wireValue ||
        result['status'] != 'pending' ||
        result['operationId'] != operationId ||
        result['invitationId'] is! String) {
      throw const FormatException(
          'Invalid invitation creation acknowledgement');
    }
  }

  Future<void> revokeInvitation({
    required String companyId,
    required CompanyInvitation invitation,
    required String operationId,
  }) async {
    final result = await _gateway.call('revokeCompanyInvitation', {
      'authorizationVersion': 1,
      'context': _ownerContext(companyId),
      'companyId': companyId,
      'invitationId': invitation.id,
      'role': invitation.role.wireValue,
      'warehouseIds': invitation.warehouseIds,
      'operationId': operationId,
    });
    if (result['authorizationVersion'] != 1 ||
        result['invitationId'] != invitation.id ||
        result['status'] != 'revoked' ||
        result['operationId'] != operationId) {
      throw const FormatException(
          'Invalid invitation revocation acknowledgement');
    }
  }

  Future<void> removeMemberRole({
    required String companyId,
    required CompanyStaffMember member,
    required String operationId,
  }) async {
    final result = await _gateway.call('removeCompanyMemberRole', {
      'authorizationVersion': 1,
      'context': _ownerContext(companyId),
      'companyId': companyId,
      'memberId': member.memberId,
      'role': member.role.wireValue,
      'operationId': operationId,
    });
    if (result['authorizationVersion'] != 1 ||
        result['memberId'] != member.memberId ||
        result['status'] != 'removed' ||
        result['operationId'] != operationId) {
      throw const FormatException(
          'Invalid company role removal acknowledgement');
    }
  }

  Future<void> createWarehouse({
    required String companyId,
    required String name,
    required String code,
    required String address,
    required String operationId,
  }) async {
    final result = await _gateway.call('saveCompanyWarehouse', {
      'authorizationVersion': 1,
      'context': _ownerContext(companyId),
      'companyId': companyId,
      'name': name,
      'code': code,
      'address': address,
      'operationId': operationId,
    });
    if (result['authorizationVersion'] != 1 ||
        result['warehouseId'] is! String ||
        result['status'] != 'active' ||
        result['operationId'] != operationId) {
      throw const FormatException('Invalid warehouse creation acknowledgement');
    }
  }
}

Map<String, Object?> _ownerContext(String companyId) => {
      'kind': 'company',
      'companyId': companyId,
      'role': CompanyRole.companyOwner.wireValue,
    };

import 'package:sarisupply_company/sarisupply_company.dart';
import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import '../../merchant_review/presentation/merchant_review_list_screen.dart';
import '../../company/presentation/company_workspace_screen.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate(
      {super.key,
      required this.auth,
      required this.access,
      required this.reviews,
      this.procurement,
      this.authorization});
  final AuthRepository auth;
  final AdminAccessRepository access;
  final AdminReviewRepository reviews;
  final ProcurementGateway? procurement;
  final AuthorizationWorkspaceFunctions? authorization;
  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  late Stream<AuthUser?> _authStream;
  String? _checkedUid, _error, _accountLabel;
  Future<bool>? _accessCheck;
  Future<AuthorizationWorkspacePage>? _workspaceCheck;
  Future<List<CompanyInvitation>>? _invitationCheck;
  final Map<String, String> _invitationOperationIds = {};
  bool _pending = false;
  @override
  void initState() {
    super.initState();
    _authStream = widget.auth.authStateChanges();
  }

  @override
  void didUpdateWidget(covariant AdminAuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth ||
        oldWidget.access != widget.access ||
        oldWidget.authorization != widget.authorization) {
      _authStream = widget.auth.authStateChanges();
      _checkedUid = null;
      _accessCheck = null;
      _workspaceCheck = null;
      _invitationCheck = null;
      _selectedWorkspace = null;
      _selectedPlatform = false;
    }
  }

  Future<void> _authenticate({bool signOut = false}) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      if (signOut) {
        await widget.auth.signOut();
      } else {
        await widget.auth.signInWithGoogle();
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Widget _entry(Widget child) => Scaffold(
      body: SariSupplyEntry(
          role: 'Admin',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            child,
            if (_error != null) ...[
              const SizedBox(height: 16),
              SariSupplyStatus(message: _error!, error: true)
            ],
          ])));
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthUser?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _entry(SariSupplyStatus(
              message: 'Unable to check sign-in.',
              error: true,
              actions: [
                TextButton(
                    onPressed: () => setState(() {
                          _authStream = widget.auth.authStateChanges();
                          _checkedUid = null;
                          _accessCheck = null;
                        }),
                    child: const Text('Retry'))
              ]));
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _entry(const Column(children: [
            LinearProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking sign-in…')
          ]));
        }
        final user = snapshot.data;
        _accountLabel = user?.displayName ?? user?.email;
        if (user == null) {
          _checkedUid = null;
          _accessCheck = null;
          _workspaceCheck = null;
          _invitationCheck = null;
          _selectedWorkspace = null;
          _selectedPlatform = false;
          return _entry(FilledButton(
              onPressed: _pending ? null : () => _authenticate(),
              child: Text(_pending ? 'Signing in…' : 'Sign in with Google')));
        }
        if (_checkedUid != user.uid) {
          _checkedUid = user.uid;
          _accessCheck = widget.authorization == null
              ? widget.access.isActiveAdmin()
              : null;
          _workspaceCheck =
              widget.authorization?.getAuthorizationWorkspaces(pageSize: 50);
          _invitationCheck = null;
          _selectedWorkspace = null;
          _selectedPlatform = false;
        }
        if (widget.authorization != null) {
          return FutureBuilder<AuthorizationWorkspacePage>(
            future: _workspaceCheck,
            builder: (context, result) {
              if (result.connectionState != ConnectionState.done) {
                return _entry(const Column(children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking company and platform access…'),
                ]));
              }
              if (result.hasError || !result.hasData) {
                return _entry(SariSupplyStatus(
                  message: 'Unable to verify workspace access.',
                  error: true,
                  actions: [
                    FilledButton(
                      onPressed: _pending
                          ? null
                          : () => setState(() => _workspaceCheck = widget
                              .authorization!
                              .getAuthorizationWorkspaces(pageSize: 50)),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                        onPressed: _pending
                            ? null
                            : () => _authenticate(signOut: true),
                        child: const Text('Sign out')),
                  ],
                ));
              }
              return _authorizationEntry(result.data!);
            },
          );
        }
        return FutureBuilder<bool>(
            future: _accessCheck,
            builder: (context, access) {
              if (access.connectionState != ConnectionState.done) {
                return _entry(const Column(children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking Admin access…')
                ]));
              }
              if (access.hasError) {
                return _entry(SariSupplyStatus(
                    message: 'Unable to check Admin access',
                    error: true,
                    actions: [
                      FilledButton(
                          onPressed: _pending
                              ? null
                              : () => setState(() =>
                                  _accessCheck = widget.access.isActiveAdmin()),
                          child: const Text('Retry')),
                      TextButton(
                          onPressed: _pending
                              ? null
                              : () => _authenticate(signOut: true),
                          child: const Text('Sign out')),
                    ]));
              }
              if (access.data != true) {
                return _entry(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Access denied',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      const SariSupplyStatus(
                          message:
                              'This Google account is not an active SariSupply Admin.',
                          icon: Icons.lock_outline),
                      const SizedBox(height: 24),
                      TextButton(
                          onPressed: _pending
                              ? null
                              : () => _authenticate(signOut: true),
                          child: Text(_pending ? 'Signing out…' : 'Sign out')),
                    ]));
              }
              return MerchantReviewListScreen(
                  reviews: widget.reviews,
                  onSignOut: widget.auth.signOut,
                  procurement: widget.procurement);
            });
      });

  Widget _authorizationEntry(AuthorizationWorkspacePage page) {
    final workspaces = page.workspaces
        .where((workspace) => workspace.role != CompanyRole.rider)
        .toList();
    final choices = workspaces.length + (page.canAdministerPlatform ? 1 : 0);
    if (choices == 0) {
      _invitationCheck ??= widget.authorization!.listMyInvitations();
      return _entry(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Company access', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const SariSupplyStatus(
            message:
                'This account has no active Admin or company Operations workspace. Store access remains in POS; Rider access belongs in Driver.',
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<CompanyInvitation>>(
            future: _invitationCheck,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return SariSupplyStatus(
                    message: operationErrorMessage(snapshot.error!),
                    error: true);
              }
              final invitations = (snapshot.data ?? const <CompanyInvitation>[])
                  .where((invite) =>
                      invite.role == CompanyRole.warehouseOperations);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final invitation in invitations)
                    Card(
                        child: ListTile(
                      title: Text(invitation.companyName),
                      subtitle: Text(
                          'Warehouse Operations · ${invitation.warehouseIds.length} assigned warehouse(s)'),
                      trailing: FilledButton(
                        onPressed: _pending
                            ? null
                            : () => _acceptInvitation(invitation),
                        child: Text(_pending ? 'Accepting…' : 'Accept'),
                      ),
                    )),
                ],
              );
            },
          ),
          TextButton(
              onPressed: _pending ? null : _refreshAccess,
              child: const Text('Refresh access')),
          TextButton(
              onPressed: _pending ? null : () => _authenticate(signOut: true),
              child: const Text('Sign out')),
        ],
      ));
    }
    if (_selectedPlatform && page.canAdministerPlatform) {
      return _platformWorkspace(canSwitch: choices > 1);
    }
    final selected = _selectedWorkspace;
    if (selected != null) {
      final current = workspaces.where((workspace) =>
          workspace.companyId == selected.companyId &&
          workspace.role == selected.role);
      if (current.isNotEmpty) {
        return _companyWorkspace(current.first, canSwitch: choices > 1);
      }
    }
    if (choices == 1) {
      if (page.canAdministerPlatform) return _platformWorkspace();
      return _companyWorkspace(workspaces.single);
    }
    return _entry(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a workspace',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'Company ownership and platform administration are separate access contexts.'),
        const SizedBox(height: 16),
        if (page.canAdministerPlatform)
          Card(
              child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Platform Administration'),
            subtitle: const Text('Merchant application review'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _selectedPlatform = true),
          )),
        for (final workspace in workspaces)
          Card(
              child: ListTile(
            leading: const Icon(Icons.business_outlined),
            title: Text(workspace.displayName),
            subtitle: Text(_companyRoleName(workspace.role)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _selectedWorkspace = workspace),
          )),
        TextButton(
            onPressed: _pending ? null : () => _authenticate(signOut: true),
            child: const Text('Sign out')),
      ],
    ));
  }

  AuthorizationWorkspace? _selectedWorkspace;
  bool _selectedPlatform = false;

  void _refreshAccess() {
    setState(() {
      _error = null;
      _workspaceCheck =
          widget.authorization!.getAuthorizationWorkspaces(pageSize: 50);
      _invitationCheck = null;
    });
  }

  Future<void> _acceptInvitation(CompanyInvitation invitation) async {
    if (_pending) return;
    final uid = _checkedUid;
    final key = '$uid:${invitation.companyId}:${invitation.id}';
    final operationId =
        _invitationOperationIds.putIfAbsent(key, () => const Uuid().v4());
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.authorization!.acceptInvitation(invitation, operationId);
      _invitationOperationIds.remove(key);
      if (mounted && _checkedUid == uid) _refreshAccess();
    } catch (error) {
      if (mounted && _checkedUid == uid) {
        setState(() => _error = operationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Widget _platformWorkspace({bool canSwitch = false}) =>
      MerchantReviewListScreen(
        reviews: widget.reviews,
        onSignOut: widget.auth.signOut,
        procurement: widget.procurement,
        onSwitchContext: canSwitch
            ? () => setState(() {
                  _selectedWorkspace = null;
                  _selectedPlatform = false;
                })
            : null,
      );

  Widget _companyWorkspace(AuthorizationWorkspace workspace,
          {bool canSwitch = false}) =>
      CompanyOperationsScreen(
        key: ValueKey(
            '${workspace.companyId}:${workspace.role.wireValue}:${workspace.membershipRevision}:${workspace.roleGrantRevision}'),
        authorizationRevision:
            '${workspace.membershipRevision}:${workspace.roleGrantRevision}',
        companyId: workspace.companyId,
        title: workspace.displayName,
        context: workspace.context,
        onSignOut: () => _authenticate(signOut: true),
        onExit: canSwitch
            ? () => setState(() {
                  _selectedWorkspace = null;
                  _selectedPlatform = false;
                })
            : null,
        onAdministration: () => Navigator.of(context).push<int>(
          MaterialPageRoute<int>(
              builder: (pageContext) => CompanyWorkspaceScreen(
                    onNavigate: (index) => Navigator.of(pageContext).pop(index),
                    accountLabel: _accountLabel,
                    workspace: workspace,
                    authorization: widget.authorization!,
                    onSwitchContext: canSwitch
                        ? () {
                            Navigator.of(context).pop();
                            setState(() {
                              _selectedWorkspace = null;
                              _selectedPlatform = false;
                            });
                          }
                        : null,
                    onSignOut: () async {
                      await widget.auth.signOut();
                      if (mounted) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    },
                  )),
        ),
      );

  String _companyRoleName(CompanyRole role) => switch (role) {
        CompanyRole.companyOwner => 'Company Owner',
        CompanyRole.warehouseOperations => 'Warehouse Operations',
        CompanyRole.rider => 'Rider',
      };
}

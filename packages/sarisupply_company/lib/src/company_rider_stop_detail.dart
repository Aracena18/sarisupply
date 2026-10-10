import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

import 'company_delivery_payment.dart';

class CompanyRiderStopDetail extends StatefulWidget {
  const CompanyRiderStopDetail({
    super.key,
    required this.stop,
    required this.stopCount,
    required this.awaitingDispatch,
    required this.busy,
    required this.actionsEnabled,
    required this.directionsOpened,
    required this.deliveryStarted,
    required this.itemsConfirmed,
    required this.paymentConfirmed,
    required this.onDirections,
    required this.onDeliveryStarted,
    required this.onItemsConfirmed,
    required this.onPaymentConfirmed,
    required this.onProof,
    this.initialProgress = const {},
    this.onSaveProgress,
    this.onRecordDelivery,
  });

  final Map<String, Object?> stop;
  final int stopCount;
  final bool awaitingDispatch, busy, actionsEnabled;
  final bool directionsOpened, deliveryStarted, itemsConfirmed;
  final bool paymentConfirmed;
  final VoidCallback onDirections, onDeliveryStarted;
  final VoidCallback onItemsConfirmed, onPaymentConfirmed;
  final Future<bool> Function() onProof;
  final Map<String, Object?> initialProgress;
  final Future<bool> Function(Map<String, Object?> progress)? onSaveProgress;
  final Future<bool> Function(Map<String, Object?> delivery)? onRecordDelivery;

  @override
  State<CompanyRiderStopDetail> createState() => _CompanyRiderStopDetailState();
}

class _CompanyRiderStopDetailState extends State<CompanyRiderStopDetail> {
  final _paymentFormKey = GlobalKey<FormState>();
  final _proofFormKey = GlobalKey<FormState>();
  final _cashController = TextEditingController();
  final _paymentIssueController = TextEditingController();
  final _recipientController = TextEditingController();
  final _notesController = TextEditingController();

  late int _step;
  late String _recipientRole;
  late List<Map<String, Object?>> _items;
  late Map<String, int> _delivered;
  late Map<String, int> _returned;
  late Map<String, String> _returnReasons;
  bool _saving = false;
  String? _draftError;
  Future<void> _draftWrites = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _items = _readItems();
    final progress = widget.initialProgress;
    _delivered = {};
    _returned = {};
    _returnReasons = {};
    _restoreItems(progress['items']);
    _cashController.text = progress['cashCollectedText']?.toString() ?? '';
    _paymentIssueController.text = progress['paymentIssue']?.toString() ?? '';
    _recipientController.text = progress['recipientName']?.toString() ?? '';
    _recipientRole = progress['recipientRole']?.toString() ?? 'Store Owner';
    _notesController.text = progress['notes']?.toString() ?? '';

    if (widget.awaitingDispatch) {
      _step = -1;
    } else if (widget.stop['proof'] != null) {
      _step = 6;
    } else if (progress['step'] is num &&
        (progress['step'] as num).toInt() >= 0 &&
        (progress['step'] as num).toInt() <= 5) {
      _step = (progress['step'] as num).toInt();
    } else if (!widget.directionsOpened) {
      _step = 0;
    } else if (!widget.deliveryStarted) {
      _step = 1;
    } else if (!widget.itemsConfirmed) {
      _step = 2;
    } else if (_needsCashCollection && !widget.paymentConfirmed) {
      _step = 3;
    } else {
      _step = 4;
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    _paymentIssueController.dispose();
    _recipientController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> _readItems() =>
      (widget.stop['items'] as List? ?? const [])
          .map((raw) => Map<String, Object?>.from(raw as Map))
          .toList();

  String _itemKey(Map<String, Object?> item, int index) =>
      item['productId']?.toString().trim().isNotEmpty == true
      ? item['productId'].toString()
      : 'line-$index';

  int _ordered(Map<String, Object?> item) =>
      (item['quantityOrdered'] as num?)?.toInt() ?? 0;

  int _unitCost(Map<String, Object?> item) =>
      (item['unitCostCentavos'] as num?)?.toInt() ?? 0;

  void _restoreItems(Object? value) {
    final savedItems = value is List ? value.whereType<Map>().toList() : [];
    final savedById = <String, Map>{};
    for (final item in savedItems) {
      final id = item['productId']?.toString();
      if (id != null) savedById[id] = item;
    }
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final key = _itemKey(item, i);
      final saved =
          savedById[key] ?? (widget.stop['proof'] != null ? item : null);
      final ordered = _ordered(item);
      var delivered = (saved?['quantityDelivered'] as num?)?.toInt() ?? ordered;
      var returned = (saved?['quantityReturned'] as num?)?.toInt() ?? 0;
      delivered = delivered.clamp(0, ordered);
      returned = returned.clamp(0, ordered);
      if (delivered + returned != ordered) {
        delivered = ordered;
        returned = 0;
      }
      _delivered[key] = delivered;
      _returned[key] = returned;
      _returnReasons[key] = saved?['returnReason']?.toString() ?? '';
    }
  }

  String get _paymentMethod => companyDeliveryPaymentMethod(widget.stop);

  bool get _isCod => _paymentMethod == companyCashOnDelivery;
  bool get _isQr => _paymentMethod == companyQrPayment;

  int get _units => _items.fold<int>(0, (sum, item) => sum + _ordered(item));

  int _totalValue() => _items.fold<int>(
    0,
    (sum, item) => sum + _ordered(item) * _unitCost(item),
  );

  int _deliveredValue() {
    var total = 0;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      total +=
          (_delivered[_itemKey(item, i)] ?? _ordered(item)) * _unitCost(item);
    }
    return total;
  }

  int? get _fullOrderDue {
    final raw = widget.stop['amountDueCentavos'];
    if (raw is! num) return null;
    return raw.toInt().clamp(0, _totalValue());
  }

  int? get _currentCashDue {
    final due = _fullOrderDue;
    if (due == null) return null;
    final previouslyPaid = _totalValue() - due;
    return math.max(0, _deliveredValue() - previouslyPaid);
  }

  int get _cashCollected => _parseMoney(_cashController.text) ?? 0;

  bool get _needsCashCollection =>
      _isCod && (_currentCashDue == null || _currentCashDue! > 0);

  String get _instructions =>
      [
            widget.stop['deliveryInstructions'],
            widget.stop['instructions'],
            widget.stop['notes'],
          ]
          .map((value) => value?.toString().trim() ?? '')
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');

  int? _parseMoney(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;
    if (!RegExp(r'^[0-9]+([.][0-9]{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final pesos = int.tryParse(parts.first);
    if (pesos == null) return null;
    final centavos = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));
    return pesos * 100 + centavos;
  }

  String _peso(int centavos) => '₱${(centavos / 100).toStringAsFixed(2)}';

  List<Map<String, Object?>> _confirmedItems() => [
    for (var i = 0; i < _items.length; i++)
      {
        ..._items[i],
        'quantityDelivered': _delivered[_itemKey(_items[i], i)] ?? 0,
        'quantityReturned': _returned[_itemKey(_items[i], i)] ?? 0,
        'returnReason': _returnReasons[_itemKey(_items[i], i)] ?? '',
      },
  ];

  Map<String, Object?> _snapshot({int? step}) => {
    'version': 1,
    'step': step ?? _step,
    'directionsOpened': step == null ? _step >= 1 : step >= 1,
    'deliveryStarted': step == null ? _step >= 2 : step >= 2,
    'itemsConfirmed': step == null ? _step >= 3 : step >= 3,
    'paymentConfirmed':
        _needsCashCollection && (step == null ? _step >= 4 : step >= 4),
    'items': _confirmedItems(),
    'cashCollectedText': _cashController.text,
    'paymentIssue': _paymentIssueController.text,
    'recipientName': _recipientController.text,
    'recipientRole': _recipientRole,
    'notes': _notesController.text,
  };

  void _queueDraftSave() {
    final save = widget.onSaveProgress;
    if (save == null || _step < 0 || _step > 4) return;
    final snapshot = _snapshot();
    _draftWrites = _draftWrites
        .catchError((Object _) {})
        .then((_) async {
          final saved = await save(snapshot);
          if (!saved && mounted) {
            setState(
              () => _draftError = 'Could not save progress on this phone.',
            );
          } else if (mounted && _draftError != null) {
            setState(() => _draftError = null);
          }
        })
        .catchError((Object _) {
          if (mounted) {
            setState(
              () => _draftError = 'Could not save progress on this phone.',
            );
          }
        });
  }

  Future<bool> _persistStep(int nextStep) async {
    await _draftWrites.catchError((Object _) {});
    final save = widget.onSaveProgress;
    if (save == null) return true;
    try {
      final saved = await save(_snapshot(step: nextStep));
      if (mounted) {
        setState(
          () => _draftError = saved
              ? null
              : 'Could not save progress on this phone. Try again.',
        );
      }
      return saved;
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _draftError = 'Could not save progress on this phone. Try again.',
        );
      }
      return false;
    }
  }

  Future<void> _advanceTo(int nextStep) async {
    if (!await _persistStep(nextStep) || !mounted) return;
    setState(() {
      _step = nextStep;
      _draftError = null;
    });
  }

  Future<void> _handlePrimary() async {
    if (_saving || !widget.actionsEnabled || widget.busy) return;
    switch (_step) {
      case 0:
        widget.onDirections();
        await _advanceTo(1);
        break;
      case 1:
        if (!await _persistStep(_items.isEmpty ? _stepAfterItems : 2)) return;
        widget.onDeliveryStarted();
        if (!mounted) return;
        setState(() => _step = _items.isEmpty ? _stepAfterItems : 2);
        break;
      case 2:
        if (!_validateItems()) return;
        final next = _stepAfterItems;
        if (!await _persistStep(next)) return;
        widget.onItemsConfirmed();
        if (!mounted) return;
        setState(() => _step = next);
        break;
      case 3:
        if (_currentCashDue == null) {
          _showError(
            'Payment details are unavailable. Contact warehouse operations.',
          );
          return;
        }
        if (!(_paymentFormKey.currentState?.validate() ?? false)) return;
        if (!await _persistStep(4)) return;
        widget.onPaymentConfirmed();
        if (mounted) setState(() => _step = 4);
        break;
      case 4:
        if (!(_proofFormKey.currentState?.validate() ?? false)) return;
        await _recordDelivery();
        break;
      case 5:
        Navigator.of(context).pop(true);
        break;
      case 6:
        Navigator.of(context).pop(false);
        break;
    }
  }

  int get _stepAfterItems => _needsCashCollection ? 3 : 4;

  bool _validateItems() {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final key = _itemKey(item, i);
      final ordered = _ordered(item);
      if ((_delivered[key] ?? 0) + (_returned[key] ?? 0) != ordered) {
        _showError('Account for all ${item['unitName'] ?? 'units'}.');
        return false;
      }
      if ((_returned[key] ?? 0) > 0 &&
          (_returnReasons[key] ?? '').trim().isEmpty) {
        _showError('Add a reason for returned items.');
        return false;
      }
    }
    return true;
  }

  String? _cashError(String? value) {
    final amount = _parseMoney(value ?? '');
    final due = _currentCashDue;
    if (amount == null) return 'Enter an amount with up to 2 decimals.';
    if (due == null) {
      return 'Payment amount is unavailable. Contact operations.';
    }
    if (amount > due) return 'Cash collected cannot exceed ${_peso(due)}.';
    if (amount < due && _paymentIssueController.text.trim().isEmpty) {
      return 'Explain why the full COD amount was not collected.';
    }
    return null;
  }

  Future<void> _recordDelivery() async {
    if (!_validateItems()) return;
    if (_isCod && _currentCashDue == null) {
      _showError(
        'Payment amount is unavailable. Contact warehouse operations.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _draftError = null;
    });
    try {
      await _draftWrites.catchError((Object _) {});
      final progress = _snapshot(step: 4);
      final save = widget.onSaveProgress;
      if (save != null && !await save(progress)) {
        if (mounted) {
          setState(() {
            _saving = false;
            _draftError = 'Could not save progress on this phone. Try again.';
          });
        }
        return;
      }
      final recordDelivery = widget.onRecordDelivery;
      final saved = recordDelivery == null
          ? await widget.onProof()
          : await recordDelivery(progress);
      if (!mounted) return;
      if (saved) {
        setState(() {
          _step = 5;
          _draftError = null;
        });
      } else {
        setState(
          () =>
              _draftError = 'Proof was not saved. Your details are kept here.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _draftError = 'Proof was not saved. Your details are kept here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final stopNumber = (widget.stop['sequence'] as num?)?.toInt() ?? 0;
    final stopName = widget.stop['destinationName']?.toString().trim() ?? '';
    final address = widget.stop['destinationAddress']?.toString().trim() ?? '';
    final distanceKm = widget.stop['distanceKm'];
    final etaMinutes = widget.stop['etaMinutes'];
    final hasDistanceEta = distanceKm is num && etaMinutes is num;
    final packageVerified =
        widget.stop['packageManifestId']?.toString().trim().isNotEmpty ?? false;
    final proof = widget.stop['proof'] as Map?;
    final enabled =
        widget.actionsEnabled &&
        !widget.busy &&
        !_saving &&
        _step >= 0 &&
        !(_step == 3 && _currentCashDue == null);

    return Scaffold(
      backgroundColor: SariSupplyColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _header(stopNumber),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                    ),
                    children: [
                      _destination(
                        stopName,
                        address,
                        hasDistanceEta ? distanceKm : null,
                        hasDistanceEta ? etaMinutes : null,
                      ),
                      const SizedBox(height: 16),
                      _stepProgress(),
                      if (_step <= 1 || _step == -1) ...[
                        const Divider(
                          height: 32,
                          color: SariSupplyColors.divider,
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: SariSupplyColors.ink50,
                            borderRadius: BorderRadius.circular(
                              SariSupplyRadii.md,
                            ),
                          ),
                          child: _deliverySummary(
                            packageVerified: packageVerified,
                            proof: proof,
                          ),
                        ),
                        if (_items.isNotEmpty) ...[
                          const Divider(
                            height: 32,
                            color: SariSupplyColors.divider,
                          ),
                          _itemsSection(_items),
                        ],
                        if (_instructions.isNotEmpty ||
                            widget.stop['contactPerson']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true ||
                            widget.stop['contactPhone']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true) ...[
                          const Divider(
                            height: 32,
                            color: SariSupplyColors.divider,
                          ),
                          _contactAndInstructions(),
                        ],
                        if (_step == 1) _secondaryDirectionsAction(),
                      ],
                      if (_step == 2) ...[
                        const Divider(
                          height: 32,
                          color: SariSupplyColors.divider,
                        ),
                        _itemsConfirmation(),
                      ],
                      if (_step == 3) ...[
                        const Divider(
                          height: 32,
                          color: SariSupplyColors.divider,
                        ),
                        _paymentCollection(),
                      ],
                      if (_step == 4) ...[
                        const Divider(
                          height: 32,
                          color: SariSupplyColors.divider,
                        ),
                        _proofEntry(),
                      ],
                      if (_step == 5 || _step == 6) ...[
                        const Divider(
                          height: 32,
                          color: SariSupplyColors.divider,
                        ),
                        _completionSummary(proof),
                      ],
                      if (_draftError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _draftError!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: SariSupplyColors.orange700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _stickyAction(enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepProgress() {
    if (_step < 0) {
      return const _StatusRow(
        text: 'Awaiting warehouse dispatch',
        icon: Icons.schedule_outlined,
        color: SariSupplyColors.ink600,
      );
    }
    if (_step >= 5) {
      return const _StatusRow(
        text: 'Delivery recorded',
        icon: Icons.task_alt,
        color: SariSupplyColors.success,
      );
    }
    final stages = [
      (0, 'Directions'),
      (1, 'Arrival'),
      if (_items.isNotEmpty) (2, 'Items'),
      if (_needsCashCollection || _step == 3) (3, 'Collection'),
      (4, 'Proof'),
    ];
    final index = stages.indexWhere((stage) => stage.$1 == _step);
    if (index < 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SariSupplyColors.orange50,
        borderRadius: BorderRadius.circular(SariSupplyRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                stages[index].$2,
                style: SariSupplyTypography.label.copyWith(
                  color: SariSupplyColors.ink950,
                ),
              ),
              Text(
                'Step ${index + 1} of ${stages.length}',
                style: SariSupplyTypography.body.copyWith(
                  color: SariSupplyColors.ink600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: index / stages.length,
              minHeight: 4,
              color: SariSupplyColors.orange700,
              backgroundColor: SariSupplyColors.orange100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactAndInstructions() => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    title: const Text(
      'Contact & instructions',
      style: SariSupplyTypography.label,
    ),
    children: [
      if (widget.stop['contactPerson']?.toString().trim().isNotEmpty == true)
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${widget.stop['contactPerson']}',
            style: SariSupplyTypography.bodyLarge,
          ),
        ),
      if (widget.stop['contactPhone']?.toString().trim().isNotEmpty ==
          true) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            '${widget.stop['contactPhone']}',
            style: SariSupplyTypography.bodyLarge,
          ),
        ),
      ],
      if (_instructions.isNotEmpty) ...[
        const SizedBox(height: 12),
        _instructionsRow(_instructions),
      ],
    ],
  );

  Widget _header(int stopNumber) => Column(
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back,
                size: 28,
                color: SariSupplyColors.ink950,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stop $stopNumber of ${widget.stopCount}',
                style: const TextStyle(
                  fontFamily: SariSupplyTypography.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: SariSupplyColors.ink950,
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: SariSupplyColors.divider),
    ],
  );

  Widget _destination(
    String name,
    String address,
    Object? distanceKm,
    Object? etaMinutes,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (name.isNotEmpty)
        Text(
          name,
          style: const TextStyle(
            fontFamily: SariSupplyTypography.fontFamily,
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w700,
            color: SariSupplyColors.ink950,
          ),
        ),
      if (address.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 22,
              color: SariSupplyColors.ink600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                address,
                style: const TextStyle(
                  fontSize: 16,
                  color: SariSupplyColors.ink600,
                ),
              ),
            ),
          ],
        ),
      ],
      if (distanceKm is num && etaMinutes is num) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.near_me_outlined,
              size: 22,
              color: SariSupplyColors.ink600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${distanceKm.toStringAsFixed(1)} km · ~${etaMinutes.round()} min',
                style: SariSupplyTypography.body.copyWith(
                  color: SariSupplyColors.ink600,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _deliverySummary({
    required bool packageVerified,
    required Map? proof,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel('Delivery summary'),
      if (_items.isNotEmpty || _paymentSummary.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            if (_items.isNotEmpty)
              _summaryValue('$_units units', 'Total items'),
            if (_paymentSummary.isNotEmpty)
              _summaryValue(_paymentSummary, _paymentMethodLabel),
          ],
        ),
      ],
      if (packageVerified) ...[
        const SizedBox(height: 16),
        const _StatusRow(
          text: 'Package verified',
          icon: Icons.check_circle,
          color: SariSupplyColors.success,
        ),
      ],
      if (proof != null) ...[
        const SizedBox(height: 12),
        _StatusRow(
          text: 'Proof recorded · ${proof['recipientName'] ?? ''}',
          icon: Icons.check_circle,
          color: SariSupplyColors.success,
        ),
      ],
    ],
  );

  String get _paymentMethodLabel {
    if (_isCod) return 'COD due';
    if (_isQr) return 'QR payment';
    return 'Payment method unavailable';
  }

  String get _paymentSummary {
    final due = _fullOrderDue;
    if (_isCod) {
      if (due == null) return 'Amount unavailable';
      return due == 0 ? 'No amount due' : _peso(due);
    }
    if (_isQr) {
      if (due == null) return 'Status unavailable';
      final paid = math.max(0, _totalValue() - due);
      if (due == 0) return 'Confirmed · ${_peso(paid)}';
      if (paid > 0) return '${_peso(paid)} confirmed · ${_peso(due)} due';
      return '${_peso(due)} awaiting confirmation';
    }
    if (due == null) return 'Status unavailable';
    return due == 0 ? 'Amount not confirmed' : '${_peso(due)} outstanding';
  }

  String get _unavailablePaymentText {
    final due = _fullOrderDue;
    if (due == null || due == 0) return 'Payment method unavailable';
    return 'Payment method unavailable · ${_peso(due)} outstanding';
  }

  Widget _summaryValue(String value, String label) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 120, maxWidth: 260),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: SariSupplyColors.ink950,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: SariSupplyColors.ink600),
        ),
      ],
    ),
  );

  Widget _itemsSection(List<Map<String, Object?>> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Items (${items.length})',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: SariSupplyColors.ink600,
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < items.length; i++) _itemRow(items[i]),
    ],
  );

  Widget _itemRow(Map<String, Object?> item) {
    final sku = item['sku']?.toString().trim() ?? '';
    final name = item['productName']?.toString().trim() ?? '';
    final unitName = item['unitName']?.toString().trim() ?? '';
    final quantity = _ordered(item);
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SariSupplyColors.ink950,
                        ),
                      ),
                    if (sku.isNotEmpty) ...[
                      if (name.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        'SKU $sku',
                        style: const TextStyle(
                          fontSize: 14,
                          color: SariSupplyColors.ink600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: SariSupplyColors.ink950,
                    ),
                  ),
                  Text(
                    unitName.isNotEmpty ? unitName : 'units',
                    style: const TextStyle(
                      fontSize: 14,
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: SariSupplyColors.divider),
      ],
    );
  }

  Widget _itemsConfirmation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'ITEMS (${_items.length})',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: SariSupplyColors.ink600,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Confirm the quantities received.',
        style: TextStyle(fontSize: 14, color: SariSupplyColors.ink600),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _items.length; i++) _confirmItemRow(_items[i], i),
    ],
  );

  Widget _confirmItemRow(Map<String, Object?> item, int index) {
    final key = _itemKey(item, index);
    final ordered = _ordered(item);
    final returned = _returned[key] ?? 0;
    final unit = item['unitName']?.toString().trim().isNotEmpty == true
        ? item['unitName'].toString()
        : 'units';
    final sku = item['sku']?.toString().trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['productName']?.toString() ?? 'Item',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: SariSupplyColors.ink950,
                ),
              ),
              if (sku.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'SKU $sku · $ordered $unit ordered',
                  style: const TextStyle(
                    fontSize: 14,
                    color: SariSupplyColors.ink600,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '$ordered $unit ordered',
                  style: const TextStyle(
                    fontSize: 14,
                    color: SariSupplyColors.ink600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _quantityStepper(
                label: 'Delivered',
                value: _delivered[key] ?? ordered,
                maxValue: ordered,
                unit: unit,
                onDecrease: () => _adjustItem(
                  key,
                  ordered,
                  delivered: (_delivered[key] ?? ordered) - 1,
                ),
                onIncrease: () => _adjustItem(
                  key,
                  ordered,
                  delivered: (_delivered[key] ?? ordered) + 1,
                ),
              ),
              _quantityStepper(
                label: 'Returned',
                value: returned,
                maxValue: ordered,
                unit: unit,
                onDecrease: () =>
                    _adjustItem(key, ordered, returned: returned - 1),
                onIncrease: () =>
                    _adjustItem(key, ordered, returned: returned + 1),
              ),
              if (returned > 0) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('return-reason-$key'),
                  initialValue: _returnReasons[key] ?? '',
                  maxLength: 120,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Return / short delivery reason',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _returnReasons[key] = value;
                    _queueDraftSave();
                  },
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: SariSupplyColors.divider),
      ],
    );
  }

  void _adjustItem(String key, int ordered, {int? delivered, int? returned}) {
    var nextDelivered = delivered ?? _delivered[key] ?? ordered;
    var nextReturned = returned ?? _returned[key] ?? 0;
    nextDelivered = nextDelivered.clamp(0, ordered);
    nextReturned = nextReturned.clamp(0, ordered);
    if (delivered != null) nextReturned = ordered - nextDelivered;
    if (returned != null) nextDelivered = ordered - nextReturned;
    setState(() {
      _delivered[key] = nextDelivered;
      _returned[key] = nextReturned;
    });
    _queueDraftSave();
  }

  Widget _quantityStepper({
    required String label,
    required int value,
    required int maxValue,
    required String unit,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$label · $unit',
            style: const TextStyle(
              fontSize: 14,
              color: SariSupplyColors.ink600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Decrease $label',
          onPressed: value <= 0 ? null : onDecrease,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SariSupplyColors.ink950,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase $label',
          onPressed: value >= maxValue ? null : onIncrease,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );

  Widget _paymentCollection() {
    final due = _currentCashDue;
    if (due == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('PAYMENT'),
          SizedBox(height: 8),
          _StatusRow(
            text:
                'COD amount unavailable. Contact warehouse operations before collecting cash.',
            icon: Icons.info_outline,
            color: SariSupplyColors.orange500,
          ),
        ],
      );
    }
    return Form(
      key: _paymentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('PAYMENT'),
          const SizedBox(height: 8),
          const Text(
            'COD due',
            style: TextStyle(fontSize: 14, color: SariSupplyColors.ink600),
          ),
          const SizedBox(height: 4),
          Text(
            _peso(due),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: SariSupplyColors.ink950,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Cash actually collected',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
            ),
            validator: _cashError,
            onChanged: (_) {
              setState(() {});
              _queueDraftSave();
            },
          ),
          if ((_currentCashDue ?? 0) > _cashCollected) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _paymentIssueController,
              maxLength: 120,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Why wasn’t the full amount collected?',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_cashCollected < (_currentCashDue ?? 0) &&
                    (value == null || value.trim().isEmpty)) {
                  return 'A reason is required for a remaining balance.';
                }
                return null;
              },
              onChanged: (_) {
                setState(() {});
                _queueDraftSave();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _proofEntry() => Form(
    key: _proofFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('PROOF OF DELIVERY'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _recipientController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Recipient name',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Recipient name is required.'
              : null,
          onChanged: (_) => _queueDraftSave(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _recipientRole,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Recipient role',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Store Owner', child: Text('Store Owner')),
            DropdownMenuItem(
              value: 'Store Manager',
              child: Text('Store Manager'),
            ),
            DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
            DropdownMenuItem(
              value: 'Staff/Relative',
              child: Text('Staff/Relative'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _recipientRole = value);
              _queueDraftSave();
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLength: 60,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Delivery note (optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _queueDraftSave(),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: SariSupplyColors.divider),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StatusRow(
            text:
                'Items confirmed · ${_delivered.values.fold<int>(0, (sum, value) => sum + value)} units',
            icon: Icons.check_circle,
            color: SariSupplyColors.success,
          ),
        ],
        const SizedBox(height: 12),
        if (_isCod && _currentCashDue != null)
          _StatusRow(
            text:
                'Cash collected · ${_peso(_cashCollected)} of ${_peso(_currentCashDue!)}',
            icon: Icons.check_circle,
            color: _cashCollected == _currentCashDue
                ? SariSupplyColors.success
                : SariSupplyColors.orange500,
          )
        else if (_isQr)
          _StatusRow(
            text: _paymentSummary,
            icon: _fullOrderDue == 0 ? Icons.check_circle : Icons.info_outline,
            color: _fullOrderDue == 0
                ? SariSupplyColors.success
                : SariSupplyColors.orange500,
          )
        else
          _StatusRow(
            text: _unavailablePaymentText,
            icon: Icons.info_outline,
            color: SariSupplyColors.orange500,
          ),
        if (_paymentIssueController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Balance remains · ${_peso(math.max(0, (_currentCashDue ?? 0) - _cashCollected))}',
            style: const TextStyle(color: SariSupplyColors.ink600),
          ),
        ],
      ],
    ),
  );

  Widget _completionSummary(Map? proof) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel('Delivery summary'),
      const SizedBox(height: 16),
      if (_items.isNotEmpty)
        _StatusRow(
          text:
              'Items confirmed · ${_delivered.values.fold<int>(0, (sum, value) => sum + value)} units',
          icon: Icons.check_circle,
          color: SariSupplyColors.success,
        ),
      if (_isCod && _currentCashDue != null) ...[
        const SizedBox(height: 12),
        _StatusRow(
          text: 'Cash recorded · ${_peso(_cashCollected)} collected',
          icon: Icons.check_circle,
          color: _cashCollected == _currentCashDue
              ? SariSupplyColors.success
              : SariSupplyColors.orange500,
        ),
        if (_cashCollected < _currentCashDue!)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(
              'Balance remains · ${_peso(_currentCashDue! - _cashCollected)}',
              style: const TextStyle(
                fontSize: 14,
                color: SariSupplyColors.ink600,
              ),
            ),
          ),
      ],
      if (_isQr) ...[
        const SizedBox(height: 12),
        _StatusRow(
          text: _paymentSummary,
          icon: _fullOrderDue == 0 ? Icons.check_circle : Icons.info_outline,
          color: _fullOrderDue == 0
              ? SariSupplyColors.success
              : SariSupplyColors.orange500,
        ),
      ],
      if (!_isCod && !_isQr) ...[
        const SizedBox(height: 12),
        _StatusRow(
          text: _unavailablePaymentText,
          icon: Icons.info_outline,
          color: SariSupplyColors.orange500,
        ),
      ],
      const SizedBox(height: 12),
      _StatusRow(
        text:
            'Proof recorded · ${proof?['recipientName'] ?? _recipientController.text}',
        icon: Icons.check_circle,
        color: SariSupplyColors.success,
      ),
      const SizedBox(height: 12),
      const _StatusRow(
        text: 'Saved on this phone · Waiting to sync',
        icon: Icons.cloud_done_outlined,
        color: SariSupplyColors.ink600,
      ),
    ],
  );

  Widget _instructionsRow(String instructions) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Icon(
          Icons.description_outlined,
          size: 24,
          color: SariSupplyColors.ink600,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SariSupplyColors.ink950,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                instructions,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: SariSupplyColors.ink600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _secondaryDirectionsAction() => Column(
    children: [
      const Divider(height: 1, color: SariSupplyColors.divider),
      TextButton.icon(
        onPressed: widget.actionsEnabled && !widget.busy
            ? widget.onDirections
            : null,
        icon: const Icon(Icons.near_me_outlined),
        label: const Text('Open directions again'),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: SariSupplyColors.orange500,
          alignment: Alignment.centerLeft,
        ),
      ),
    ],
  );

  Widget _stickyAction(bool enabled) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    decoration: const BoxDecoration(
      color: SariSupplyColors.card,
      border: Border(top: BorderSide(color: SariSupplyColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: FilledButton.icon(
          onPressed: enabled ? _handlePrimary : null,
          icon: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SariSupplyColors.ink950,
                  ),
                )
              : Icon(_actionIcon),
          label: Text(
            _saving ? 'Saving proof…' : _actionLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: SariSupplyColors.orange500,
            foregroundColor: SariSupplyColors.ink950,
            disabledBackgroundColor: SariSupplyColors.ink50,
            disabledForegroundColor: SariSupplyColors.ink600,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ),
  );

  String get _actionLabel => switch (_step) {
    -1 => 'Awaiting dispatch',
    0 => 'Open directions',
    1 => 'Start delivery',
    2 => 'Confirm items',
    3 => _currentCashDue == null ? 'Payment unavailable' : 'Confirm collection',
    4 => 'Record proof',
    5 => 'Complete stop',
    _ => 'Next stop',
  };

  IconData get _actionIcon => switch (_step) {
    -1 => Icons.schedule_outlined,
    0 => Icons.near_me_outlined,
    1 => Icons.storefront_outlined,
    2 => Icons.checklist_outlined,
    3 => Icons.payments_outlined,
    4 => Icons.edit_outlined,
    5 => Icons.check_circle_outline,
    _ => Icons.arrow_forward,
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: SariSupplyColors.ink600,
    ),
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color == SariSupplyColors.orange500
                ? SariSupplyColors.orange700
                : color,
          ),
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class ItemRequestsScreen extends StatefulWidget {
  const ItemRequestsScreen({
    super.key,
    required this.read,
    required this.create,
    required this.respond,
    this.orderProduct,
    required this.store,
  });
  final Future<CompanyPage> Function(String? cursor) read;
  final Future<void> Function() create;
  final Future<void> Function(CompanyRecord request, bool close) respond;
  final Future<void> Function(String productId)? orderProduct;
  final bool store;
  @override
  State<ItemRequestsScreen> createState() => _ItemRequestsScreenState();
}

class _ItemRequestsScreenState extends State<ItemRequestsScreen> {
  List<CompanyRecord> _records = [];
  String? _cursor, _error;
  bool _busy = false, _more = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final page = await widget.read(more ? _cursor : null);
      if (mounted) {
        setState(() {
          _records = more ? [..._records, ...page.records] : page.records;
          _cursor = page.nextCursor;
          _more = page.hasMore;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = operationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: sariSupplyTaskAppBar(
      context,
      title: 'Item requests',
      actions: [
        IconButton(
          tooltip: 'Refresh requests',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SariSupplyPageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) SariSupplyStatus(message: _error!, error: true),
          if (widget.store)
            FilledButton.icon(
              onPressed: _busy ? null : () => _action(widget.create),
              icon: const Icon(Icons.add),
              label: const Text('Request an item'),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sourcing requests are separate from purchases. Availability and price require a confirmed order.',
            ),
          ),
          if (_records.isEmpty && !_busy) const Text('No item requests yet.'),
          for (final r in _records)
            Card(
              key: ValueKey(r.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.string('name'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${r.number('quantity')} ${r.string('unit')} · ${switch (r.status) {
                        'submitted' => 'Submitted',
                        'responded' => 'Responded',
                        _ => 'Closed',
                      }}',
                    ),
                    if (!widget.store)
                      Text(
                        '${r.string('storeName')} · ${r.string('branchName')}\n${r.string('contact')} · ${r.string('phone')}',
                      ),
                    if (r.string('details').isNotEmpty)
                      Text(r.string('details')),
                    if (r.string('response').isNotEmpty)
                      Text('Warehouse response: ${r.string('response')}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!widget.store && r.status != 'closed') ...[
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _action(() => widget.respond(r, false)),
                            child: const Text('Respond'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _action(() => widget.respond(r, true)),
                            child: const Text('Close request'),
                          ),
                        ],
                        if (widget.store &&
                            r.string('productId').isNotEmpty &&
                            widget.orderProduct != null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => widget.orderProduct!(
                                    r.string('productId'),
                                  ),
                            child: const Text('Review product and order'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_more)
            OutlinedButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Load more requests'),
            ),
        ],
      ),
    ),
  );
}

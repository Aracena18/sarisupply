import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';
import 'receipt_screen.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key, required this.controller});
  final CheckoutController controller;
  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final _query = TextEditingController();
  List<CheckoutSale> _receipts = [];
  String? _cursor, _error;
  bool _loading = true, _more = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final rows = await widget.controller.store.checkout
          .receipts(query: _query.text, cursor: append ? _cursor : null);
      final cursor = rows.isEmpty
          ? null
          : await widget.controller.store.checkout.receiptCursor(rows.last.id);
      if (!mounted || generation != _generation) return;
      setState(() {
        _receipts = append ? [..._receipts, ...rows] : rows;
        _cursor = cursor;
        _more = rows.length == 50;
        _error = null;
      });
    } on Object {
      if (mounted) {
        setState(() => _error = 'Receipts could not be loaded. Try again.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Receipts'),
      body: SariSupplyPageContent(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: _query,
            decoration: const InputDecoration(
                labelText: 'Search receipt or payment reference'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load()),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          SariSupplyStatus(message: _error!, error: true, actions: [
            TextButton(onPressed: _load, child: const Text('Retry'))
          ]),
        if (!_loading && _receipts.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('No receipts found')),
        for (final s in _receipts)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatPhp(s.totalCentavos)),
              subtitle: Text(
                  '${s.occurredAt.toLocal().toString().split('.').first} · ${s.tender.kind.toUpperCase()}\n${s.id}'),
              isThreeLine: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) =>
                      ReceiptScreen(controller: widget.controller, sale: s)))),
        if (_more)
          TextButton(
              onPressed: _loading ? null : () => _load(append: true),
              child: const Text('More receipts')),
      ])));
}

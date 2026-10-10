import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';

/// Resolve the line by product and unit after a modal rather than keeping an index.
class CheckoutQuantityControls extends StatefulWidget {
  const CheckoutQuantityControls(
      {super.key,
      required this.controller,
      required this.line,
      this.enabled = true,
      this.onBusyChanged});
  final CheckoutController controller;
  final CartLine line;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<CheckoutQuantityControls> createState() =>
      _CheckoutQuantityControlsState();
}

class _CheckoutQuantityControlsState extends State<CheckoutQuantityControls> {
  bool _busy = false;
  Future<void> _change({int? delta, bool enter = false}) async {
    if (_busy || !widget.controller.editable) return;
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      final amount = enter
          ? await showSariSupplyForm<int>(
              context: context,
              builder: (_) => _QuantityForm(line: widget.line),
            )
          : null;
      if (!mounted || (enter && amount == null)) return;
      final c = widget.controller;
      final lines = c.draft?.lines ?? <CartLine>[];
      final index = lines.indexWhere((l) =>
          l.productId == widget.line.productId && l.unit == widget.line.unit);
      if (index < 0 || !c.editable) return;
      await c.quantity(index, amount ?? lines[index].quantity + delta!);
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.controller.editable && !_busy;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      IconButton(
          tooltip: 'Decrease ${widget.line.name} ${widget.line.unit}',
          onPressed: enabled ? () => _change(delta: -1) : null,
          icon: const Icon(Icons.remove)),
      TextButton(
          onPressed: enabled ? () => _change(enter: true) : null,
          child: Text('${widget.line.quantity} × ${widget.line.unit}')),
      IconButton(
          tooltip: 'Increase ${widget.line.name} ${widget.line.unit}',
          onPressed: enabled ? () => _change(delta: 1) : null,
          icon: const Icon(Icons.add)),
    ]);
  }
}

class _QuantityForm extends StatefulWidget {
  const _QuantityForm({required this.line});
  final CartLine line;
  @override
  State<_QuantityForm> createState() => _QuantityFormState();
}

class _QuantityFormState extends State<_QuantityForm> {
  late final _value = TextEditingController(text: '${widget.line.quantity}');
  String? _error;
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(_value.text);
    try {
      if (amount == null || amount < 1) throw const FormatException();
      widget.line.withQuantity(amount);
      Navigator.of(context).pop(amount);
    } on Object {
      setState(
          () => _error = 'Enter a supported whole quantity greater than zero.');
    }
  }

  @override
  Widget build(BuildContext context) => SariSupplyFormSurface(
      title: 'Set quantity',
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Apply quantity'))
      ],
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.line.name),
            TextField(
                key: const Key('cart-quantity-input'),
                controller: _value,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: 'Quantity · ${widget.line.unit}',
                    errorText: _error),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save()),
          ]));
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'brand.dart';
import 'status_panel.dart';
import 'theme/sarisupply_theme.dart';

/// Renders startup before asynchronous platform initialization can fail.
class SariSupplyStartupGate extends StatefulWidget {
  const SariSupplyStartupGate({
    super.key,
    required this.role,
    required this.initialize,
    required this.child,
  });
  final String role;
  final Future<void> Function() initialize;
  final Widget child;
  @override
  State<SariSupplyStartupGate> createState() => _SariSupplyStartupGateState();
}

class _SariSupplyStartupGateState extends State<SariSupplyStartupGate> {
  Future<void>? _pending, _initializing;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    // A timeout does not cancel native initialization. Retry reuses in-flight work.
    final operation = _initializing ??= Future<void>.sync(widget.initialize);
    operation.then(
      (_) {
        if (identical(_initializing, operation)) _initializing = null;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_initializing, operation)) _initializing = null;
      },
    );
    _pending = operation.timeout(const Duration(seconds: 20));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _pending,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.child;
      }
      return MaterialApp(
        theme: SariSupplyTheme.light,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SariSupplyEntry(
            role: widget.role,
            child: snapshot.hasError
                ? SariSupplyStatus(
                    message:
                        'Unable to start ${widget.role}. Check your connection and try again.',
                    error: true,
                    actions: [
                      TextButton(
                        onPressed: () => setState(_start),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Starting…'),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

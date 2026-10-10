import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_core/sarisupply_core.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  const ReceiptPreviewDialog({
    super.key,
    required this.document,
    this.title = 'Receipt preview',
    this.notice,
  });

  final ReceiptDocument document;
  final String title;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is58mm = document.paperSize == EscPosPaperSize.mm58;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(is58mm ? '58 mm · 32 columns' : '80 mm · 42 columns',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close preview',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notice != null) ...[
                    Text(notice!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                  ],
                  SsCard(
                    backgroundColor: SariSupplyColors.paper,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        document.plaintext,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.35,
                          color: SariSupplyColors.ink950,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy receipt text'),
            onPressed: () async {
              try {
                await Clipboard.setData(
                    ClipboardData(text: document.plaintext));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Receipt text copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Could not copy. Try again.'),
                  ));
                }
              }
            },
          ),
          const SizedBox(height: 8),
          Text('Printing unavailable · Preview only',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: SafeArea(child: content));
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: content,
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../app/services.dart';
import '../app/theme.dart';

/// Shows the text ArmScan recognised, ready to select, copy or share.
class TextScreen extends StatelessWidget {
  const TextScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final doc = s.store.byId(documentId);
        if (doc == null) return const Scaffold();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final text = doc.fullText;
        final reading = s.store.isReadingText(doc.id);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Text'),
            actions: [
              IconButton(
                tooltip: 'Copy all text',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: text.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          showMessage(context, 'Text copied');
                        }
                      },
              ),
              IconButton(
                tooltip: 'Share text',
                icon: const Icon(Icons.ios_share),
                onPressed: text.isEmpty
                    ? null
                    : () => SharePlus.instance
                        .share(ShareParams(text: text, title: doc.name)),
              ),
            ],
          ),
          body: text.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ArmSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (reading) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: ArmSpacing.md),
                        ],
                        Text(
                          reading
                              ? 'Reading text from your pages…'
                              : 'No text was found in this scan.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(ArmSpacing.md),
                  child: SelectableText(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
        );
      },
    );
  }
}

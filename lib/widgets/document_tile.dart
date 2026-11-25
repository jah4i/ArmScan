import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../app/services.dart';
import '../app/theme.dart';
import '../models/scan_document.dart';
import 'page_thumbnail.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.doc, required this.onTap});

  final ScanDocument doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = s.store.isReadingText(doc.id);
    final pages = doc.pages.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: ArmColors.gold, width: 5)),
          ),
          padding: const EdgeInsets.all(ArmSpacing.sm + 4),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 72,
                child: PageThumbnail(
                  file: s.store.pageFile(doc, doc.pages.first),
                  cacheWidth: 168,
                ),
              ),
              const SizedBox(width: ArmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat.yMMMd().add_jm().format(doc.updatedAt)}'
                      '  ·  $pages ${pages == 1 ? 'page' : 'pages'}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: ArmSpacing.sm,
                      runSpacing: 4,
                      children: [
                        if (reading)
                          const StatusChip(
                              icon: Icons.hourglass_top,
                              label: 'Reading text',
                              tone: ChipTone.neutral)
                        else if (doc.ocrComplete && doc.fullText.isNotEmpty)
                          const StatusChip(
                              icon: Icons.text_snippet_outlined,
                              label: 'Searchable',
                              tone: ChipTone.gold),
                        if (doc.oneDriveUrl != null)
                          const StatusChip(
                              icon: Icons.cloud_done_outlined,
                              label: 'OneDrive',
                              tone: ChipTone.dark),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

enum ChipTone { gold, dark, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone = ChipTone.neutral,
  });

  final IconData icon;
  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      ChipTone.gold => (ArmColors.gold, ArmColors.black),
      ChipTone.dark => (ArmColors.gray700, Colors.white),
      ChipTone.neutral => (scheme.surfaceContainerLow, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }
}

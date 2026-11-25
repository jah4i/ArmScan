import 'package:material_ui/material_ui.dart';

import '../app/services.dart';
import '../app/theme.dart';
import '../models/scan_document.dart';
import '../widgets/page_thumbnail.dart';
import 'page_viewer_screen.dart';
import 'text_screen.dart';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

enum _Busy { none, share, save, onedrive, add }

class _DocumentScreenState extends State<DocumentScreen> {
  _Busy _busy = _Busy.none;

  Future<void> _run(_Busy kind, Future<void> Function() action) async {
    if (_busy != _Busy.none) return;
    setState(() => _busy = kind);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _rename(ScanDocument doc) async {
    final controller = TextEditingController(text: doc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Document name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && mounted) {
      await Services.of(context).store.rename(doc, name);
    }
  }

  Future<void> _delete(ScanDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: Text(
          '"${doc.name}" and its ${doc.pages.length} page(s) will be removed '
          'from this device. Copies already saved to OneDrive or Files are '
          'not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final store = Services.of(context).store;
      Navigator.of(context).pop();
      await store.delete(doc);
    }
  }

  Future<void> _deletePage(ScanDocument doc, ScanPage page) async {
    final s = Services.of(context);
    if (doc.pages.length == 1) return _delete(doc);
    await s.store.deletePage(doc, page);
    if (mounted) showMessage(context, 'Page deleted');
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.store, s.oneDrive]),
      builder: (context, _) {
        final doc = s.store.byId(widget.documentId);
        if (doc == null) return const Scaffold();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => _rename(doc),
              child: Text(doc.name, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(doc),
              ),
              IconButton(
                tooltip: 'Delete scan',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(doc),
              ),
            ],
          ),
          body: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              ArmSpacing.md,
              0,
              ArmSpacing.md,
              ArmSpacing.lg,
            ),
            header: Padding(
              padding: const EdgeInsets.only(bottom: ArmSpacing.sm + 4),
              child: Text(
                '${doc.pages.length} ${doc.pages.length == 1 ? 'page' : 'pages'}'
                '${doc.pages.length > 1 ? '  ·  Hold and drag to reorder' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: ArmSpacing.sm),
              child: OutlinedButton.icon(
                onPressed: _busy != _Busy.none
                    ? null
                    : () => _run(_Busy.add, () async {
                        final pages = await s.scanner.scan(
                          context,
                          saveLabel: 'Add',
                        );
                        if (pages.isNotEmpty) {
                          await s.store.addPages(doc, pages);
                        }
                      }),
                icon: const Icon(Icons.add),
                label: const Text('Add pages'),
              ),
            ),
            itemCount: doc.pages.length,
            onReorderItem: (from, to) => s.store.reorderPage(doc, from, to),
            itemBuilder: (context, i) {
              final page = doc.pages[i];
              return Padding(
                key: ValueKey(page.fileName),
                padding: const EdgeInsets.only(bottom: ArmSpacing.md),
                child: _PageCard(
                  index: i,
                  page: page,
                  doc: doc,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PageViewerScreen(documentId: doc.id, initialPage: i),
                    ),
                  ),
                  onDelete: () => _deletePage(doc, page),
                ),
              );
            },
          ),
          bottomNavigationBar: _ActionBar(
            busy: _busy,
            onShare: (ctx) => _run(_Busy.share, () => s.sharePdf(ctx, doc)),
            onSave: () => _run(_Busy.save, () async {
              final saved = await s.savePdfToDevice(doc);
              if (saved && context.mounted) showMessage(context, 'PDF saved');
            }),
            onOneDrive: () => _run(_Busy.onedrive, () async {
              if (!s.oneDrive.isConfigured) {
                showMessage(
                  context,
                  'OneDrive is not set up in this build yet. See Settings.',
                );
                return;
              }
              await s.uploadToOneDrive(doc);
              if (context.mounted) {
                showMessage(context, 'Saved to OneDrive / ArmScan');
              }
            }),
            onText: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TextScreen(documentId: doc.id)),
            ),
            savedToOneDrive: doc.oneDriveUrl != null,
          ),
        );
      },
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.index,
    required this.page,
    required this.doc,
    required this.onOpen,
    required this.onDelete,
  });

  final int index;
  final ScanPage page;
  final ScanDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = page.height == 0 ? 0.77 : page.width / page.height;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(ArmSpacing.sm + 4),
              child: AspectRatio(
                aspectRatio: ratio,
                child: Semantics(
                  label: 'Page ${index + 1}. Tap to view full screen.',
                  image: true,
                  child: PageThumbnail(
                    file: s.store.pageFile(doc, page),
                    cacheWidth: 900,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(left: ArmSpacing.md),
            child: Row(
              children: [
                Text(
                  'Page ${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: ArmSpacing.sm),
                if (!page.hasOcr)
                  Text(
                    'Reading text…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete page ${index + 1}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.drag_handle,
                      semanticLabel: 'Drag to reorder',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onShare,
    required this.onSave,
    required this.onOneDrive,
    required this.onText,
    required this.savedToOneDrive,
  });

  final _Busy busy;
  final void Function(BuildContext) onShare;
  final VoidCallback onSave;
  final VoidCallback onOneDrive;
  final VoidCallback onText;
  final bool savedToOneDrive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ArmColors.black,
        border: Border(top: BorderSide(color: ArmColors.gold, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ArmSpacing.xs),
          child: Row(
            children: [
              Builder(
                builder: (ctx) => _Action(
                  icon: Icons.ios_share,
                  label: 'Share PDF',
                  loading: busy == _Busy.share,
                  onTap: busy == _Busy.none ? () => onShare(ctx) : null,
                ),
              ),
              _Action(
                icon: Icons.save_alt,
                label: 'Save PDF',
                loading: busy == _Busy.save,
                onTap: busy == _Busy.none ? onSave : null,
              ),
              _Action(
                icon: savedToOneDrive
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_upload_outlined,
                label: 'OneDrive',
                loading: busy == _Busy.onedrive,
                onTap: busy == _Busy.none ? onOneDrive : null,
              ),
              _Action(
                icon: Icons.text_snippet_outlined,
                label: 'Text',
                loading: false,
                onTap: onText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null && !loading
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.white;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ArmRadius.button),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  child: loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Icon(
                          icon,
                          color: onTap == null ? color : ArmColors.gold,
                        ),
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

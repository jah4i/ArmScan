import 'package:material_ui/material_ui.dart';

import '../app/services.dart';
import '../app/theme.dart';
import '../models/scan_document.dart';
import '../widgets/document_tile.dart';
import 'document_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan({bool fromGallery = false}) async {
    final s = Services.of(context);
    setState(() => _busy = true);
    try {
      final paths = await s.scanner.scan(fromGallery: fromGallery);
      if (paths.isEmpty || !mounted) return;
      final doc = await s.store.createFromImages(paths);
      if (!mounted) return;
      _maybeAutoUpload(doc);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DocumentScreen(documentId: doc.id),
      ));
    } catch (e) {
      if (mounted) showMessage(context, 'Could not scan: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _maybeAutoUpload(ScanDocument doc) {
    final s = Services.of(context);
    if (!s.settings.autoUploadToOneDrive || !s.oneDrive.isSignedIn) return;
    final messenger = ScaffoldMessenger.of(context);
    s.uploadToOneDrive(doc).then(
      (_) => messenger.showSnackBar(
          SnackBar(content: Text('Saved "${doc.name}" to OneDrive'))),
      onError: (Object e) => messenger
          .showSnackBar(SnackBar(content: Text('OneDrive upload failed: $e'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ArmScan'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: ArmSpacing.xs),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          if (!s.store.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = s.store.documents;
          if (all.isEmpty) return const _EmptyState();

          final docs = all.where((d) => d.matches(_query)).toList();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    ArmSpacing.md, ArmSpacing.sm, ArmSpacing.md, ArmSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search names and text in scans',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('No scans match "$_query"',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      ArmSpacing.md, 0, ArmSpacing.md, 120),
                  sliver: SliverList.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: ArmSpacing.sm + 4),
                    itemBuilder: (context, i) => DocumentTile(
                      key: ValueKey(docs[i].id),
                      doc: docs[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DocumentScreen(documentId: docs[i].id),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: _ScanBar(
        busy: _busy,
        onScan: () => _scan(),
        onImport: () => _scan(fromGallery: true),
      ),
    );
  }
}

class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.busy,
    required this.onScan,
    required this.onImport,
  });

  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              ArmSpacing.md, ArmSpacing.sm + 4, ArmSpacing.md, ArmSpacing.sm + 4),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan document'),
                ),
              ),
              const SizedBox(width: ArmSpacing.sm + 4),
              Tooltip(
                message: 'Import from photos',
                child: OutlinedButton(
                  onPressed: busy ? null : onImport,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(56, 52),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      semanticLabel: 'Import from photos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ArmSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.description_outlined,
                  size: 40, color: scheme.primary),
            ),
            const SizedBox(height: ArmSpacing.lg),
            Text('No scans yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: ArmSpacing.sm),
            Text(
              'Point your camera at a document. ArmScan finds the edges, '
              'captures it automatically and reads the text.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

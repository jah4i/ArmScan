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
      final paths = fromGallery
          ? await s.scanner.importFromGallery()
          : await s.scanner.scan(context);
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
        toolbarHeight: 64,
        title: Image.asset('assets/brand/logo_on_dark.png',
            height: 40, semanticLabel: 'ArmScan'),
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
          final pageCount = all.fold<int>(0, (n, d) => n + d.pages.length);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  docCount: all.length,
                  pageCount: pageCount,
                  search: TextField(
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
              const SliverToBoxAdapter(child: SizedBox(height: ArmSpacing.md)),
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

/// Black band under the app bar with library totals and search.
class _Header extends StatelessWidget {
  const _Header({
    required this.docCount,
    required this.pageCount,
    required this.search,
  });

  final int docCount;
  final int pageCount;
  final Widget search;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: ArmColors.black,
      padding: const EdgeInsets.fromLTRB(
          ArmSpacing.md, ArmSpacing.xs, ArmSpacing.md, ArmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stat(value: '$docCount', label: docCount == 1 ? 'scan' : 'scans'),
              const SizedBox(width: ArmSpacing.lg),
              _Stat(value: '$pageCount', label: pageCount == 1 ? 'page' : 'pages'),
            ],
          ),
          const SizedBox(height: ArmSpacing.md),
          Theme(
            data: theme.copyWith(
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                fillColor: Colors.white,
                hintStyle: const TextStyle(color: Color(0xFF6B6B6B)),
                prefixIconColor: ArmColors.gray700,
                suffixIconColor: ArmColors.gray700,
              ),
              textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: ArmColors.black),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: ArmColors.black),
              child: search,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value,
            style: const TextStyle(
                color: ArmColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: ArmColors.gray300,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
      ],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ArmColors.black,
        border: Border(top: BorderSide(color: ArmColors.gold, width: 3)),
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
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: ArmColors.gray500, width: 1.5),
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
              decoration: const BoxDecoration(
                color: ArmColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_outlined,
                  size: 40, color: ArmColors.black),
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

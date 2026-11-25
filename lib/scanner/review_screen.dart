import 'dart:io';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import 'captured_page.dart';
import 'paper.dart';

/// What the user chose on the review screen.
enum ReviewAction { save, addMore, discard }

/// Shows every captured page before saving. Pages can be viewed full screen,
/// reordered (hold and drag), deleted, switched between B&W, Gray and Color,
/// and set to a paper size. Changes are made to [session] in place.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.session,
    this.canAddMore = true,
    this.saveLabel = 'Save',
  });

  final ScanSession session;
  final bool canAddMore;
  final String saveLabel;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<CapturedPage> get _pages => widget.session.pages;

  /// Pages whose image is being rebuilt with new settings.
  final Set<CapturedPage> _rendering = {};

  /// Bumped on every settings change so late results of an older change are
  /// thrown away instead of overwriting the newer one.
  int _generation = 0;

  // ------------------------------------------------------------- settings

  Future<void> _applySettings(ColorMode mode, PaperChoice paper) async {
    final s = widget.session;
    if (s.mode == mode && s.paper == paper) return;
    setState(() {
      s.mode = mode;
      s.paper = paper;
      _rendering.addAll(_pages);
    });
    final gen = ++_generation;
    final queue = [..._pages];

    // Two at a time: quick, without holding many full-size pages in memory.
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final page = queue.removeAt(0);
        if (gen != _generation) return;
        try {
          final r = await renderAgain(page, mode, paper);
          if (gen == _generation && _pages.contains(page)) {
            page.apply(r, mode);
          } else {
            File(r.path).deleteSync();
          }
        } catch (e) {
          debugPrint('Re-render failed: $e');
        }
        if (gen == _generation && mounted) {
          setState(() => _rendering.remove(page));
        }
      }
    }

    await Future.wait([worker(), worker()]);
    if (gen == _generation && mounted) setState(_rendering.clear);
  }

  // ---------------------------------------------------------------- pages

  void _move(CapturedPage page, int to) {
    final from = _pages.indexOf(page);
    if (from < 0 || from == to) return;
    setState(() {
      _pages.removeAt(from);
      _pages.insert(to.clamp(0, _pages.length), page);
    });
    HapticFeedback.selectionClick();
  }

  void _delete(CapturedPage page) {
    final index = _pages.indexOf(page);
    if (index < 0) return;
    setState(() => _pages.removeAt(index));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: Text('Page ${index + 1} deleted'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: ArmColors.gold,
              onPressed: () {
                if (!mounted || _pages.contains(page)) return;
                setState(
                  () => _pages.insert(index.clamp(0, _pages.length), page),
                );
              },
            ),
          ),
        )
        .closed
        .then((reason) {
          if (reason != SnackBarClosedReason.action && !_pages.contains(page)) {
            page.deleteFiles();
          }
        });
  }

  Future<void> _open(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PageViewer(pages: _pages, initialPage: index, onDelete: _delete),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _discard() async {
    if (_pages.isEmpty) {
      Navigator.of(context).pop(ReviewAction.discard);
      return;
    }
    final n = _pages.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard $n scanned ${n == 1 ? 'page' : 'pages'}?'),
        content: const Text('Nothing from this scan will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(ReviewAction.discard);
  }

  void _addMore() => Navigator.of(context).pop(ReviewAction.addMore);

  void _save() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pop(ReviewAction.save);
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final n = _pages.length;
    final busy = _rendering.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.canAddMore ? _addMore() : _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Discard scan',
            icon: const Icon(Icons.close),
            onPressed: _discard,
          ),
          title: Text(n == 1 ? 'Review 1 page' : 'Review $n pages'),
        ),
        body: Column(
          children: [
            _SettingsBar(
              mode: s.mode,
              paper: s.paper,
              onMode: (m) => _applySettings(m, s.paper),
              onPaper: (p) => _applySettings(s.mode, p),
            ),
            Expanded(
              child: n == 0
                  ? const _NoPages()
                  : _PageGrid(
                      pages: _pages,
                      rendering: _rendering,
                      onMove: _move,
                      onOpen: _open,
                      onDelete: _delete,
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          canAddMore: widget.canAddMore,
          saveLabel: n <= 1 ? widget.saveLabel : '${widget.saveLabel} $n pages',
          onAddMore: _addMore,
          onSave: n == 0 || busy ? null : _save,
          busy: busy,
        ),
      ),
    );
  }
}

class _SettingsBar extends StatelessWidget {
  const _SettingsBar({
    required this.mode,
    required this.paper,
    required this.onMode,
    required this.onPaper,
  });

  final ColorMode mode;
  final PaperChoice paper;
  final ValueChanged<ColorMode> onMode;
  final ValueChanged<PaperChoice> onPaper;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ArmColors.black,
      padding: const EdgeInsets.fromLTRB(
        ArmSpacing.md,
        ArmSpacing.xs,
        ArmSpacing.md,
        ArmSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Segmented<ColorMode>(
            label: 'Mode',
            values: ColorMode.values,
            selected: mode,
            text: (m) => m.label,
            onChanged: onMode,
          ),
          const SizedBox(height: ArmSpacing.sm + 4),
          _Segmented<PaperChoice>(
            label: 'Paper size',
            values: PaperChoice.values,
            selected: paper,
            text: (p) => p.label,
            onChanged: onPaper,
          ),
        ],
      ),
    );
  }
}

/// A row of pill buttons on the black bar; the selected one is gold.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.label,
    required this.values,
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              color: ArmColors.gray300,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: ArmColors.gray700,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                for (final v in values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: v == selected,
                      label: '$label ${text(v)}',
                      excludeSemantics: true,
                      onTap: () => onChanged(v),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: v == selected
                                ? ArmColors.gold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            text(v),
                            style: TextStyle(
                              color: v == selected
                                  ? ArmColors.black
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Two-column grid. Hold a page and drag it onto another position; the
/// other pages move out of the way while dragging.
class _PageGrid extends StatelessWidget {
  const _PageGrid({
    required this.pages,
    required this.rendering,
    required this.onMove,
    required this.onOpen,
    required this.onDelete,
  });

  final List<CapturedPage> pages;
  final Set<CapturedPage> rendering;
  final void Function(CapturedPage, int) onMove;
  final void Function(int) onOpen;
  final void Function(CapturedPage) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ArmSpacing.md,
              ArmSpacing.md,
              ArmSpacing.md,
              ArmSpacing.sm,
            ),
            child: Text(
              pages.length > 1
                  ? 'Tap a page to view it. Hold and drag to reorder.'
                  : 'Tap the page to view it.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ArmSpacing.md,
            0,
            ArmSpacing.md,
            ArmSpacing.lg,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: ArmSpacing.md,
              crossAxisSpacing: ArmSpacing.md,
              childAspectRatio: 0.68,
            ),
            itemCount: pages.length,
            itemBuilder: (context, i) {
              final page = pages[i];
              return LayoutBuilder(
                key: ObjectKey(page),
                builder: (context, box) {
                  final tile = _PageTile(
                    page: page,
                    index: i,
                    busy: rendering.contains(page),
                    onOpen: () => onOpen(i),
                    onDelete: () => onDelete(page),
                  );
                  return DragTarget<CapturedPage>(
                    onWillAcceptWithDetails: (d) {
                      if (d.data != page) onMove(d.data, i);
                      return true;
                    },
                    builder: (context, _, _) => Semantics(
                      customSemanticsActions: {
                        if (i > 0)
                          const CustomSemanticsAction(
                            label: 'Move earlier',
                          ): () =>
                              onMove(page, i - 1),
                        if (i < pages.length - 1)
                          const CustomSemanticsAction(
                            label: 'Move later',
                          ): () =>
                              onMove(page, i + 1),
                      },
                      child: LongPressDraggable<CapturedPage>(
                        data: page,
                        onDragStarted: HapticFeedback.mediumImpact,
                        feedback: SizedBox(
                          width: box.maxWidth,
                          height: box.maxHeight,
                          child: Transform.scale(
                            scale: 1.05,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 12,
                              shadowColor: Colors.black,
                              child: tile,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.25, child: tile),
                        child: tile,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.index,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
  });

  final CapturedPage page;
  final int index;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ArmRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 34),
              child: Image.file(
                File(page.rendered),
                fit: BoxFit.contain,
                cacheWidth: 420,
                gaplessPlayback: true,
                semanticLabel: 'Page ${index + 1}',
              ),
            ),
          ),
          if (busy)
            const ColoredBox(
              color: Color(0x66FFFFFF),
              child: Center(
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: ArmColors.goldDeep,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 28),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ArmColors.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: ArmColors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              tooltip: 'Delete page ${index + 1}',
              onPressed: onDelete,
              icon: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: ArmColors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Text(
              '${page.paper?.label ?? 'As scanned'}  ·  ${page.mode.label}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPages extends StatelessWidget {
  const _NoPages();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ArmSpacing.xl),
        child: Text(
          'All pages were deleted. Add more pages, or close to discard.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canAddMore,
    required this.saveLabel,
    required this.onAddMore,
    required this.onSave,
    required this.busy,
  });

  final bool canAddMore;
  final String saveLabel;
  final VoidCallback onAddMore;
  final VoidCallback? onSave;
  final bool busy;

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
            ArmSpacing.md,
            ArmSpacing.sm + 4,
            ArmSpacing.md,
            ArmSpacing.sm + 4,
          ),
          child: Row(
            children: [
              if (canAddMore) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: ArmColors.gray500,
                        width: 1.5,
                      ),
                    ),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add more'),
                  ),
                ),
                const SizedBox(width: ArmSpacing.sm + 4),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.check),
                  label: Text(saveLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen swipeable view of the pages, with pinch to zoom.
class _PageViewer extends StatefulWidget {
  const _PageViewer({
    required this.pages,
    required this.initialPage,
    required this.onDelete,
  });

  final List<CapturedPage> pages;
  final int initialPage;
  final void Function(CapturedPage) onDelete;

  @override
  State<_PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<_PageViewer> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _deleteCurrent() {
    final page = widget.pages[_index];
    widget.onDelete(page);
    if (widget.pages.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index = _index.clamp(0, widget.pages.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pages.length;
    return Scaffold(
      backgroundColor: ArmColors.charcoal,
      appBar: AppBar(
        title: Text('Page ${_index + 1} of $n'),
        actions: [
          IconButton(
            tooltip: 'Delete this page',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCurrent,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: n,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final page = widget.pages[i];
          return InteractiveViewer(
            key: ObjectKey(page),
            maxScale: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(ArmSpacing.md),
                child: Image.file(
                  File(page.rendered),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  semanticLabel: 'Page ${i + 1}',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

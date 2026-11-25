import 'package:material_ui/material_ui.dart';

import '../app/services.dart';

/// Full-screen, pinch-to-zoom page viewer with swipe between pages.
class PageViewerScreen extends StatefulWidget {
  const PageViewerScreen({
    super.key,
    required this.documentId,
    required this.initialPage,
  });

  final String documentId;
  final int initialPage;

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final doc = s.store.byId(widget.documentId);
    if (doc == null) return const Scaffold();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Page ${_index + 1} of ${doc.pages.length}',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: doc.pages.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.file(
              s.store.pageFile(doc, doc.pages[i]),
              fit: BoxFit.contain,
              semanticLabel: 'Page ${i + 1}',
            ),
          ),
        ),
      ),
    );
  }
}

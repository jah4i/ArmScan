import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// How to use ArmScan: one short card per feature.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _topics = <_Topic>[
    _Topic(
      Icons.document_scanner_outlined,
      'Scan a document',
      [
        'Tap Scan document and point the camera at the page.',
        'ArmScan finds the edges and outlines the page. The outline turns '
            'gold as it holds steady, then the page is captured '
            'automatically.',
        'Tap AUTO to switch to MANUAL if you prefer to press the shutter '
            'yourself. The lightning button turns the light on.',
        'After each page choose Retake, Next page, or Done.',
      ],
    ),
    _Topic(
      Icons.grid_view_rounded,
      'Review before saving',
      [
        'Done shows all your pages before anything is saved.',
        'Tap a page to see it full screen and pinch to zoom.',
        'Hold a page and drag it to change the order.',
        'Tap the X to delete a page. Undo brings it back.',
        'Add more returns to the camera. Save keeps the document.',
      ],
    ),
    _Topic(
      Icons.contrast,
      'Black and white, Gray, or Color',
      [
        'Pages start in black and white, like a photocopy: shadows are '
            'removed, the paper comes out white and text comes out crisp.',
        'Choose Gray or Color on the review screen for photos, highlights '
            'or colored forms. The original color is kept, so you can '
            'switch back and forth before saving.',
      ],
    ),
    _Topic(
      Icons.straighten,
      'Page sizes',
      [
        'Auto recognizes Letter, Legal and A4 pages and sets the exact size, '
            'so the PDF prints at the right size.',
        'Pick Letter, Legal or A4 on the review screen to set the size '
            'yourself. Receipts, cards and other shapes keep their own '
            'shape on Auto.',
      ],
    ),
    _Topic(
      Icons.photo_library_outlined,
      'Import from photos',
      [
        'Tap the photo button next to Scan document to use pictures you '
            'already took. Each one is cropped, straightened and cleaned up '
            'the same way.',
      ],
    ),
    _Topic(
      Icons.manage_search,
      'Text and search',
      [
        'ArmScan reads the text on every page by itself. While it works, '
            'the scan shows "Reading text".',
        'Search on the home screen finds scans by name or by any word on '
            'their pages.',
        'Open a scan and tap Text to copy or share the words.',
      ],
    ),
    _Topic(
      Icons.description_outlined,
      'Your scans',
      [
        'Tap a scan to open it. Tap its name or the pencil to rename it.',
        'Add pages, drag pages to reorder them, or delete pages at any time.',
      ],
    ),
    _Topic(
      Icons.picture_as_pdf_outlined,
      'Share and save as PDF',
      [
        'Share PDF sends the scan by email, message or any app.',
        'Save PDF stores it in a folder you choose on your phone.',
        'The PDF is searchable: you can find and copy text in any PDF reader.',
      ],
    ),
    _Topic(
      Icons.cloud_upload_outlined,
      'OneDrive',
      [
        'Sign in under Settings > Microsoft OneDrive.',
        'Tap OneDrive in a scan to save it as a PDF in the ArmScan folder '
            'of your OneDrive. A cloud with a tick means it is saved.',
        'Turn on "Upload new scans automatically" to send every new scan.',
      ],
    ),
    _Topic(
      Icons.lightbulb_outline,
      'Tips for the best scans',
      [
        'Use even light and avoid your own shadow on the page.',
        'Place the page on a darker surface so the edges stand out.',
        'Hold the phone flat above the page with all four corners in view.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            ArmSpacing.md, ArmSpacing.md, ArmSpacing.md, ArmSpacing.xl),
        itemCount: _topics.length,
        separatorBuilder: (_, _) => const SizedBox(height: ArmSpacing.sm + 4),
        itemBuilder: (context, i) => _TopicCard(topic: _topics[i]),
      ),
    );
  }
}

class _Topic {
  const _Topic(this.icon, this.title, this.points);
  final IconData icon;
  final String title;
  final List<String> points;
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});
  final _Topic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ArmSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: ArmColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(topic.icon, color: ArmColors.black, size: 22),
                ),
                const SizedBox(width: ArmSpacing.sm + 4),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(topic.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ArmSpacing.sm + 4),
            for (final p in topic.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: ArmColors.goldDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(p,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45, color: scheme.onSurface)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

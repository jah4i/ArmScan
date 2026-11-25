import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// A page image decoded at a small size ([cacheWidth]) so long lists stay
/// fast and memory-light, with a hairline border like a sheet of paper.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({
    super.key,
    required this.file,
    this.cacheWidth = 400,
    this.fit = BoxFit.cover,
  });

  final File file;
  final int cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.file(
          file,
          cacheWidth: cacheWidth,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Center(
            child: Icon(Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

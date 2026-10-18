import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/mushaf_layout_models.dart';
import '../services/mushaf_coordinate_mapper.dart';

/// Geometry masking mode for Visual Recall overlays.
enum MaskBoundaryMode {
  /// Raw axis-aligned bounding rectangles directly from layout metadata.
  raw,

  /// Micro-inset (0.5 SVG points contraction on shared line boundaries).
  microInset,

  /// Subtle rounded corners (R = 3.0 pt) for calligraphic visual softening.
  rounded,
}

/// Custom painter that translates SVG viewBox Ayah geometry segments into solid opaque mask fills.
///
/// Supports both [AyahRectSegment] (line corridors on Pages 3..604) and [AyahPolygonSegment]
/// (calligraphic boundary paths on Pages 1..2).
class VisualMaskPainter extends CustomPainter {
  const VisualMaskPainter({
    required this.maskedAyahs,
    this.currentAyah,
    required this.viewBox,
    this.mapper = const MushafCoordinateMapper(),
    required this.maskColor,
    this.boundaryMode = MaskBoundaryMode.raw,
  });

  /// The list of Ayah geometry bounds on the current page to be visually masked.
  final List<AyahBounds> maskedAyahs;

  /// The active Ayah currently in focus, if any.
  final AyahBounds? currentAyah;

  /// Native SVG viewBox rect for the page.
  final Rect viewBox;

  /// Coordinate mapper service translating viewBox units to local canvas points.
  final MushafCoordinateMapper mapper;

  /// Solid opaque color used to conceal the Quranic text (matches page canvas/ink).
  final Color maskColor;

  /// Boundary adjustment mode.
  final MaskBoundaryMode boundaryMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || viewBox.isEmpty || maskedAyahs.isEmpty) return;

    final maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;

    for (final ayah in maskedAyahs) {
      _paintAyahGeometry(canvas, size, ayah, maskPaint);
    }
  }

  void _paintAyahGeometry(
    Canvas canvas,
    Size size,
    AyahBounds ayah,
    Paint paint,
  ) {
    for (final segment in ayah.segments) {
      if (segment is AyahRectSegment) {
        Rect effectiveRect = segment.rect;

        if (boundaryMode == MaskBoundaryMode.microInset) {
          // Contract horizontal edges by 0.5 SVG points if not full-width
          final isLeftEdge = effectiveRect.left <= (viewBox.left + 2.0);
          final isRightEdge = effectiveRect.right >= (viewBox.right - 2.0);
          final insetLeft = isLeftEdge ? 0.0 : 0.5;
          final insetRight = isRightEdge ? 0.0 : 0.5;
          effectiveRect = Rect.fromLTRB(
            effectiveRect.left + insetLeft,
            effectiveRect.top,
            effectiveRect.right - insetRight,
            effectiveRect.bottom,
          );
        }

        final localRect = mapper.viewBoxRectToLocal(
          viewBoxRect: effectiveRect,
          contentSize: size,
          viewBox: viewBox,
          padding: EdgeInsets.zero, // Exact 1:1 match with SvgPicture.asset inside the Stack
        );

        if (boundaryMode == MaskBoundaryMode.rounded) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(localRect, const Radius.circular(3.0)),
            paint,
          );
        } else {
          canvas.drawRect(localRect, paint);
        }
      } else if (segment is AyahPolygonSegment) {
        final localPath = mapper.viewBoxPathToLocal(
          points: segment.points,
          contentSize: size,
          viewBox: viewBox,
          padding: EdgeInsets.zero, // Exact 1:1 match with SvgPicture.asset inside the Stack
        );
        canvas.drawPath(localPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant VisualMaskPainter oldDelegate) {
    return oldDelegate.maskColor != maskColor ||
        oldDelegate.viewBox != viewBox ||
        oldDelegate.boundaryMode != boundaryMode ||
        oldDelegate.currentAyah != currentAyah ||
        !listEquals(oldDelegate.maskedAyahs, maskedAyahs);
  }
}

/// Repaint-isolated widget rendering the solid opaque visual mask layer over a Mushaf page.
class MushafVisualMaskOverlay extends StatelessWidget {
  const MushafVisualMaskOverlay({
    super.key,
    required this.maskedAyahs,
    this.currentAyah,
    required this.viewBox,
    this.mapper = const MushafCoordinateMapper(),
    required this.maskColor,
    this.boundaryMode = MaskBoundaryMode.raw,
  });

  final List<AyahBounds> maskedAyahs;
  final AyahBounds? currentAyah;
  final Rect viewBox;
  final MushafCoordinateMapper mapper;
  final Color maskColor;
  final MaskBoundaryMode boundaryMode;

  @override
  Widget build(BuildContext context) {
    if (maskedAyahs.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: VisualMaskPainter(
            maskedAyahs: maskedAyahs,
            currentAyah: currentAyah,
            viewBox: viewBox,
            mapper: mapper,
            maskColor: maskColor,
            boundaryMode: boundaryMode,
          ),
        ),
      ),
    );
  }
}

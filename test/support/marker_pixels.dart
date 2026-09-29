// Rendu d'un peintre de marqueur en pixels, pour les tests du liseré de
// détachement (canvas de design du 2026-09-29) : ce qui se voit — un pixel
// blanc juste hors du contour noir — plutôt que la liste des appels de dessin.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fond des rendus : un magenta qui n'existe dans aucun marqueur, pour que
/// « pas de liseré » se lise « le pixel est encore du magenta ».
const Color markerTestBackground = Color(0xFFFF00FF);

/// Rend [painter] dans une boîte carrée de [side] px sur [markerTestBackground]
/// et rend les pixels RGBA, lus par [pixelOf].
Future<ByteData> renderMarker(
  WidgetTester tester,
  CustomPainter painter,
  int side,
) async {
  final ByteData? data = await tester.runAsync<ByteData?>(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
      Paint()..color = markerTestBackground,
    );
    painter.paint(canvas, Size.square(side.toDouble()));
    final ui.Image image = await recorder.endRecording().toImage(side, side);
    return image.toByteData();
  });
  return data!;
}

/// Comme [renderMarker], mais sur fond TRANSPARENT et dans un canevas agrandi
/// d'une marge de [margin] px de chaque côté : le marqueur, peint dans sa
/// boîte de [side] px décalée de [margin], laisse voir ce qui déborde. Rend
/// les pixels du canevas de côté `side + 2 * margin`.
Future<ByteData> renderMarkerInMargin(
  WidgetTester tester,
  CustomPainter painter,
  int side,
  int margin,
) async {
  final int full = side + 2 * margin;
  final ByteData? data = await tester.runAsync<ByteData?>(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..translate(margin.toDouble(), margin.toDouble());
    painter.paint(canvas, Size.square(side.toDouble()));
    final ui.Image image = await recorder.endRecording().toImage(full, full);
    return image.toByteData();
  });
  return data!;
}

/// Le pixel ([x], [y]) d'un rendu carré de [side] px, en ARGB entier.
int pixelOf(ByteData data, int side, int x, int y) {
  final int offset = (y * side + x) * 4;
  final int r = data.getUint8(offset);
  final int g = data.getUint8(offset + 1);
  final int b = data.getUint8(offset + 2);
  final int a = data.getUint8(offset + 3);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

/// Vrai si [argb] est blanc, à l'anticrénelage près : le fond est magenta
/// (vert nul) et le contour noir (tout nul), seul le blanc a les trois
/// canaux hauts.
bool looksWhite(int argb, {int minChannel = 0xC0}) =>
    ((argb >> 16) & 0xFF) >= minChannel &&
    ((argb >> 8) & 0xFF) >= minChannel &&
    (argb & 0xFF) >= minChannel;

/// Vrai si [argb] est sombre (le contour noir), à l'anticrénelage près.
bool looksBlack(int argb, {int maxChannel = 0x60}) =>
    ((argb >> 16) & 0xFF) <= maxChannel &&
    ((argb >> 8) & 0xFF) <= maxChannel &&
    (argb & 0xFF) <= maxChannel;

/// Vrai si le pixel [argb] est non transparent (alpha non nul).
bool isPainted(int argb) => ((argb >> 24) & 0xFF) != 0;

/// Vrai si un pixel non transparent se trouve HORS de la boîte de [side] px
/// posée à [margin] dans un canevas de [renderMarkerInMargin].
bool paintsOutsideBox(ByteData data, int side, int margin) {
  final int full = side + 2 * margin;
  for (int y = 0; y < full; y++) {
    for (int x = 0; x < full; x++) {
      final bool inside =
          x >= margin && x < margin + side && y >= margin && y < margin + side;
      if (!inside && isPainted(pixelOf(data, full, x, y))) {
        return true;
      }
    }
  }
  return false;
}

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'riso/riso.dart';

/// PNG/JPEG 등 인코딩된 이미지 → 스트레이트 알파 RGBA.
Future<RgbaImage> decodeToRgba(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) throw StateError('픽셀을 읽지 못함');
      return RgbaImage(image.width, image.height, data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// 디코드 없이 크기만 읽는다.
Future<ui.Size> readImageSize(Uint8List encoded) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
  try {
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final size = ui.Size(desc.width.toDouble(), desc.height.toDouble());
    desc.dispose();
    return size;
  } finally {
    buffer.dispose();
  }
}

/// RGBA → PNG. 엔진이 새로 그리므로 EXIF(위치 등)는 들어가지 않는다.
Future<Uint8List> encodePng(RgbaImage im) async {
  // decodeImageFromPixels(rgba8888)는 프리멀티 알파를 기대한다.
  final src = im.pixels;
  final pre = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 4) {
    final a = src[i + 3];
    pre[i] = (src[i] * a + 127) ~/ 255;
    pre[i + 1] = (src[i + 1] * a + 127) ~/ 255;
    pre[i + 2] = (src[i + 2] * a + 127) ~/ 255;
    pre[i + 3] = a;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pre,
    im.width,
    im.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('PNG 인코딩 실패');
    return png.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// 같은 사진이면 같은 어긋남이 나오도록 픽셀에서 시드를 만든다(FNV-1a, 표본 추출).
int seedFrom(RgbaImage im) {
  var h = 0x811C9DC5;
  final p = im.pixels;
  for (var i = 0; i < p.length; i += 997) {
    h = ((h ^ p[i]) * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

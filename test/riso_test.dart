import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:urienicon/riso/riso.dart';

/// 중심 (cx,cy) 반지름 r 원판. 명도는 [shade] 또는 위→아래 그라데이션.
RgbaImage disk(
  int w,
  int h, {
  double? cx,
  double? cy,
  double? r,
  int? shade,
  List<(int, int, int)> specks = const [],
}) {
  final im = RgbaImage.blank(w, h);
  final x0 = cx ?? w / 2, y0 = cy ?? h / 2, rad = r ?? math.min(w, h) * 0.35;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - x0, 2) + math.pow(y + 0.5 - y0, 2),
      );
      final a = (rad - d + 0.5).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final v = shade ?? (40 + 180 * y / h).round();
      final o = (y * w + x) * 4;
      im.pixels
        ..[o] = v
        ..[o + 1] = v
        ..[o + 2] = v
        ..[o + 3] = (a * 255).round();
    }
  }
  for (final (sx, sy, size) in specks) {
    for (var y = sy; y < sy + size; y++) {
      for (var x = sx; x < sx + size; x++) {
        final o = (y * w + x) * 4;
        im.pixels
          ..[o] = 0
          ..[o + 3] = 255;
      }
    }
  }
  return im;
}

(double, double) centroid(Float32List v, int s) {
  var sx = 0.0, sy = 0.0, sw = 0.0;
  for (var i = 0; i < v.length; i++) {
    sx += v[i] * (i % s);
    sy += v[i] * (i ~/ s);
    sw += v[i];
  }
  return (sx / sw, sy / sw);
}

void main() {
  test('전경이 없으면 ArgumentError', () {
    expect(() => renderRiso(RgbaImage.blank(64, 64)), throwsArgumentError);
  });

  test('foregroundRatio는 알파 128 이상 비율', () {
    final im = RgbaImage.blank(10, 10);
    for (var i = 0; i < 25; i++) {
      im.pixels[i * 4 + 3] = 200;
    }
    im.pixels[99 * 4 + 3] = 127; // 반투명은 제외
    expect(foregroundRatio(im), closeTo(0.25, 1e-9));
  });

  test('출력 크기·구석: 투명판은 알파 0, 종이판은 #f3ede0', () {
    final out = renderRiso(disk(300, 200));
    expect(out.transparent.width, 512);
    expect(out.paper.height, 512);
    expect(out.transparent.pixels[3], 0);
    final p = out.paper.pixels;
    // 종이에도 그레인이 있으므로 ±6 허용
    expect(p[0], closeTo(0xF3, 6));
    expect(p[1], closeTo(0xED, 6));
    expect(p[2], closeTo(0xE0, 6));
    expect(p[3], 255);
  });

  test('같은 시드면 같은 결과, 시드가 다르면 다른 결과', () {
    final src = disk(256, 256);
    final a = renderRiso(src, const RisoParams(seed: 3));
    final b = renderRiso(src, const RisoParams(seed: 3));
    final c = renderRiso(src, const RisoParams(seed: 4));
    expect(a.transparent.pixels, b.transparent.pixels);
    expect(a.transparent.pixels, isNot(c.transparent.pixels));
  });

  test('시그니처: 블루 판이 마스크 대비 (+6,+5) 어긋남', () {
    // 균일 회색 원판이면 블루 판은 윤곽선만 남는다(그림자·선 없음).
    final out = renderRiso(
      disk(400, 400, shade: 150),
      const RisoParams(dropout: 0),
    );
    final (mx, my) = centroid(out.plates.mask, 512);
    final (bx, by) = centroid(out.plates.blue, 512);
    expect(bx - mx, closeTo(6, 1.0));
    expect(by - my, closeTo(5, 1.0));
  });

  test('흰 테두리 11px 안은 불투명 흰색, 재단선 바깥은 투명', () {
    final out = renderRiso(disk(400, 400, shade: 150));
    final m = out.plates.mask;
    // 가운데 행에서 실루엣 왼쪽 끝 찾기
    const y = 256;
    var edgeX = 0;
    while (m[y * 512 + edgeX] < 0.5) {
      edgeX++;
    }
    final px = out.transparent.pixels;
    int alphaAt(int x) => px[(y * 512 + x) * 4 + 3];
    int redAt(int x) => px[(y * 512 + x) * 4];
    expect(alphaAt(edgeX - 8), 255); // 테두리 안(블루 어긋남은 오른쪽이라 왼쪽은 흰 종이)
    expect(redAt(edgeX - 8), greaterThan(235));
    expect(alphaAt(edgeX - 20), 0); // 11 + 2 + 1.5 바깥
  });

  test('잉크 빠짐은 잉크 면적의 3~6%(설계 4%)', () {
    final src = disk(400, 400);
    final full = renderRiso(src, const RisoParams(dropout: 0, seed: 9));
    final drop = renderRiso(src, const RisoParams(seed: 9));
    var inked = 0, lost = 0;
    for (var i = 0; i < full.plates.pink.length; i++) {
      if (full.plates.pink[i] > 0.3) {
        inked++;
        if (drop.plates.pink[i] < full.plates.pink[i] * 0.5) lost++;
      }
    }
    final ratio = lost / inked;
    expect(ratio, inInclusiveRange(0.03, 0.06), reason: '실제 $ratio');
  });

  test('작은 잡티는 지우고 배치에 영향을 주지 않음', () {
    final clean = renderRiso(disk(400, 400, cx: 200, cy: 200, r: 120));
    final noisy = renderRiso(
      disk(
        400,
        400,
        cx: 200,
        cy: 200,
        r: 120,
        specks: [(5, 5, 4), (380, 390, 5)],
      ),
    );
    expect(noisy.transparent.pixels, clean.transparent.pixels);
  });

  test('골든: 합성 이미지 변환 결과가 기준과 같다', () {
    final out = renderRiso(disk(320, 360, cx: 160, cy: 190, r: 140));
    final file = File('test/goldens/riso_disk.png');
    final actual = img.Image.fromBytes(
      width: 512,
      height: 512,
      bytes: out.paper.pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    if (Platform.environment['UPDATE_GOLDENS'] == '1') {
      file
        ..createSync(recursive: true)
        ..writeAsBytesSync(img.encodePng(actual));
      markTestSkipped('골든 갱신: ${file.path}');
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'UPDATE_GOLDENS=1 로 골든을 먼저 만드세요');
    final golden = img.decodePng(file.readAsBytesSync())!;
    final g = golden.getBytes(order: img.ChannelOrder.rgba);
    final a = out.paper.pixels;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - g[i]).abs() > 2) diff++;
    }
    // 플랫폼 간 부동소수 차이 허용: 채널의 0.1% 이하
    expect(diff / a.length, lessThan(0.001), reason: '다른 채널 $diff개');
  });
}

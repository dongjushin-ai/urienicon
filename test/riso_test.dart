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
    // 왼쪽은 블루 어긋남(+6,+5) 반대편이라 순수 흰 종이.
    expect(alphaAt(edgeX - 10), 255); // 테두리 11px 안
    expect(redAt(edgeX - 10), greaterThan(235));
    expect(alphaAt(edgeX - 12), 0); // 테두리와 재단선 사이 2px 틈
    expect(
      alphaAt(edgeX - 14),
      greaterThan(0),
    ); // 재단선(점선이라 일부는 0일 수 있어 아래 테스트에서 확인)
    expect(alphaAt(edgeX - 20), 0); // 재단선 바깥
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

  test('재단선은 꼬리처럼 뻗은 곳에서도 점선(5 on / 3 off)', () {
    // 원판 + 오른쪽으로 길게 뻗은 꼬리(가로 막대).
    final im = disk(600, 300, cx: 150, cy: 150, r: 110, shade: 150);
    for (var y = 135; y < 165; y++) {
      for (var x = 150; x < 590; x++) {
        final o = (y * 600 + x) * 4;
        im.pixels
          ..[o] = 150
          ..[o + 1] = 150
          ..[o + 2] = 150
          ..[o + 3] = 255;
      }
    }
    final out = renderRiso(im, const RisoParams(dropout: 0));
    final m = out.plates.mask;
    // 꼬리 가운데 x에서 꼬리 윗변 찾기
    const x0 = 380;
    var top = 0;
    while (m[top * 512 + x0] < 0.5) {
      top++;
    }
    final y = top - 14; // 재단선 중심(테두리 11 + 틈 2 + 0.75)
    final px = out.transparent.pixels;
    var run = 0, maxRun = 0, flips = 0;
    var prev = false;
    for (var x = 330; x < 430; x++) {
      final on = px[(y * 512 + x) * 4 + 3] > 64;
      if (on) {
        run++;
        maxRun = math.max(maxRun, run);
      } else {
        run = 0;
      }
      if (on != prev) flips++;
      prev = on;
    }
    expect(maxRun, lessThanOrEqualTo(7), reason: '실선 구간 $maxRun px');
    expect(flips, greaterThanOrEqualTo(20), reason: '점선 전환 $flips회');
  });

  test('잉크 빠짐은 블루 판에도 적용', () {
    final src = disk(400, 400);
    final full = renderRiso(src, const RisoParams(dropout: 0, seed: 9));
    final drop = renderRiso(src, const RisoParams(seed: 9));
    var inked = 0, lost = 0;
    for (var i = 0; i < full.plates.blue.length; i++) {
      if (full.plates.blue[i] > 0.3) {
        inked++;
        if (drop.plates.blue[i] < full.plates.blue[i] * 0.5) lost++;
      }
    }
    expect(lost / inked, inInclusiveRange(0.02, 0.08));
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

  test('골든: 합성 이미지 변환 결과(종이·투명)가 기준과 같다', () {
    final out = renderRiso(disk(320, 360, cx: 160, cy: 190, r: 140));
    final update = Platform.environment['UPDATE_GOLDENS'] == '1';
    for (final (name, im) in [
      ('riso_disk.png', out.paper),
      ('riso_disk_transparent.png', out.transparent),
    ]) {
      final file = File('test/goldens/$name');
      if (update) {
        final png = img.Image.fromBytes(
          width: 512,
          height: 512,
          bytes: im.pixels.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        file
          ..createSync(recursive: true)
          ..writeAsBytesSync(img.encodePng(png));
        continue;
      }
      expect(
        file.existsSync(),
        isTrue,
        reason: 'UPDATE_GOLDENS=1 로 골든을 먼저 만드세요',
      );
      final g = img
          .decodePng(file.readAsBytesSync())!
          .getBytes(order: img.ChannelOrder.rgba);
      final a = im.pixels;
      var diff = 0;
      for (var i = 0; i < a.length; i++) {
        if ((a[i] - g[i]).abs() > 2) diff++;
      }
      // 플랫폼 간 부동소수 차이 허용: 채널의 0.1% 이하
      expect(diff / a.length, lessThan(0.001), reason: '$name 다른 채널 $diff개');
    }
    if (update) markTestSkipped('골든 갱신');
  });
}

// 리소 2판 스티커 변환 — CPU 기준 구현.
//
// docs/style.md(확정) 규칙을 따른다.
// - 판은 핑크(면, 명도 하프톤)·블루(선·그림자) 2개, 둘 다 곱하기 합성
// - 블루 판은 (+6,+5)px 어긋남
// - 잉크 빠짐 + 전체 그레인 35%
// - 흰 테두리 11px + 바깥 점선 재단선
//
// Flutter에 의존하지 않는 순수 Dart라 단위 테스트·Isolate·CLI에서 그대로 쓴다.
// GPU 셰이더 경로는 이 구현의 결과를 기준(정답)으로 삼는다.
import 'dart:math' as math;
import 'dart:typed_data';

/// 스트레이트 알파 RGBA8888 이미지.
class RgbaImage {
  RgbaImage(this.width, this.height, this.pixels)
    : assert(pixels.length == width * height * 4);

  RgbaImage.blank(this.width, this.height)
    : pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List pixels;
}

/// 변환 파라미터. 기본값은 docs/style.md 확정값.
class RisoParams {
  const RisoParams({
    this.size = 512,
    this.cell = 6,
    this.pinkAngle = 15,
    this.blueAngle = 75,
    this.offsetX = 6,
    this.offsetY = 5,
    this.border = 11,
    this.contour = 4,
    this.edgeLow = 0.10,
    this.edgeHigh = 0.28,
    this.shadowLevel = 0.22,
    this.dropout = 0.04,
    this.grain = 0.35,
    this.seed = 1,
  });

  /// 출력 한 변(px).
  final int size;

  /// 망점 셀 크기(px).
  final double cell;

  /// 판별 망점 각도(도).
  final double pinkAngle;
  final double blueAngle;

  /// 블루 판 어긋남(px).
  final int offsetX;
  final int offsetY;

  /// 흰 테두리 두께(px). 0~16.
  final double border;

  /// 블루 판 윤곽선 두께(px).
  final double contour;

  /// Sobel 기울기를 선으로 바꾸는 구간(정규화 명도 기준).
  final double edgeLow;
  final double edgeHigh;

  /// 이 명도 아래는 블루 판 그림자 망점.
  final double shadowLevel;

  /// 잉크가 빠지는 면적 비율(0~1).
  final double dropout;

  /// 그레인 세기(0~1).
  final double grain;

  /// 같은 시드면 같은 결과.
  final int seed;

  RisoParams copyWith({
    double? cell,
    int? offsetX,
    int? offsetY,
    double? border,
    double? grain,
    double? dropout,
    int? seed,
  }) => RisoParams(
    size: size,
    cell: cell ?? this.cell,
    pinkAngle: pinkAngle,
    blueAngle: blueAngle,
    offsetX: offsetX ?? this.offsetX,
    offsetY: offsetY ?? this.offsetY,
    border: border ?? this.border,
    contour: contour,
    edgeLow: edgeLow,
    edgeHigh: edgeHigh,
    shadowLevel: shadowLevel,
    dropout: dropout ?? this.dropout,
    grain: grain ?? this.grain,
    seed: seed ?? this.seed,
  );

  /// 테두리·어긋남·재단선이 캔버스 밖으로 나가지 않게 두는 여백.
  int get margin =>
      (border + math.max(offsetX.abs(), offsetY.abs()) + 6).ceil();
}

/// docs/style.md 팔레트.
const int kPaper = 0xF3EDE0;
const int kPink = 0xFF4FA3;
const int kBlue = 0x2F4FB8;

/// 판 데이터(테스트·디버그용). 값은 0~1 잉크 농도, 캔버스 좌표.
class RisoPlates {
  RisoPlates(this.size, this.mask, this.pink, this.blue, this.sticker);
  final int size;

  /// 배치된 전경 마스크.
  final Float32List mask;

  /// 핑크 판(어긋남 적용 전 = 기준 위치).
  final Float32List pink;

  /// 블루 판(어긋남 적용 후 최종 위치).
  final Float32List blue;

  /// 흰 스티커 종이 영역(테두리 포함) 알파.
  final Float32List sticker;
}

class RisoOutput {
  RisoOutput(this.transparent, this.paper, this.plates);

  /// 배경 투명 PNG용.
  final RgbaImage transparent;

  /// 종이색(#f3ede0) 배경. 카톡 기본 전송용.
  final RgbaImage paper;
  final RisoPlates plates;
}

/// 알파 128 이상 픽셀 비율. 0이면 전경 없음.
double foregroundRatio(RgbaImage cutout) {
  final p = cutout.pixels;
  var n = 0;
  for (var i = 3; i < p.length; i += 4) {
    if (p[i] >= 128) n++;
  }
  return n / (cutout.width * cutout.height);
}

/// 오려낸 이미지(배경 투명)를 리소 스티커로 바꾼다.
///
/// 전경이 없으면 [ArgumentError].
RisoOutput renderRiso(RgbaImage cutout, [RisoParams p = const RisoParams()]) {
  final s = p.size;
  final n = s * s;

  // 1. 잡티 덩어리 제거 → 전경 bbox → 여백 안 정사각에 맞춰 배치.
  final src = _dropSpecks(cutout);
  final box = _alphaBounds(src);
  if (box == null) {
    throw ArgumentError('전경이 없는 이미지');
  }
  final avail = s - 2 * p.margin;
  final scale = math.min(avail / box.w, avail / box.h);
  final dw = box.w * scale, dh = box.h * scale;
  final ox = (s - dw) / 2, oy = (s - dh) / 2;

  final mask = Float32List(n);
  final lum = Float32List(n);
  _place(src, box, scale, ox, oy, s, mask, lum);

  // 2. 대비 자동 보정(전경 안 상하위 2%).
  _autoLevels(lum, mask);

  // 3. 거리장: 전경 바깥 거리(테두리·재단선), 안쪽 거리(윤곽선).
  final distOut = _chamfer(mask, s, inside: false);
  final distIn = _chamfer(mask, s, inside: true);
  // 실루엣에서 떨어진 반투명 털·그림자 안개는 버린다(어두운 채팅 배경에서 회색으로 보임).
  for (var i = 0; i < n; i++) {
    if (mask[i] < 0.5 && distOut[i] > 1.5) mask[i] = 0;
  }

  final rnd = _Hash(p.seed);
  final pinkRot = _Rot(p.pinkAngle);
  final blueRot = _Rot(p.blueAngle);

  // 4. 핑크 판: 명도 하프톤.
  final pink = Float32List(n);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final i = y * s + x;
      final m = mask[i];
      if (m <= 0) continue;
      final d = 0.08 + 0.92 * math.pow(1 - lum[i], 0.9).toDouble();
      pink[i] = m * _dot(x + 0.5, y + 0.5, d, p.cell, pinkRot);
    }
  }

  // 5. 블루 판(기준 위치): Sobel 선 + 윤곽선 + 그림자 망점.
  final edge = _sobel(_blur3(lum, s), s);
  final blueBase = Float32List(n);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final i = y * s + x;
      final m = mask[i];
      if (m <= 0) continue;
      // 윤곽선: 경계에서 안쪽으로 contour px.
      final c = _clamp01(p.contour - distIn[i] + 0.5);
      // 실루엣 경계의 Sobel은 윤곽선과 겹치므로 안쪽에서만.
      final inner = _clamp01((distIn[i] - p.contour) / 2);
      final e = _smooth(p.edgeLow, p.edgeHigh, edge[i]) * inner;
      final sd = _smooth(p.shadowLevel, 0, lum[i]) * 0.85;
      final sh = sd > 0 ? _dot(x + 0.5, y + 0.5, sd, p.cell, blueRot) : 0.0;
      blueBase[i] = m * math.max(c, math.max(e, sh));
    }
  }

  // 6. 잉크 빠짐(판마다 다른 시드) — 저주파 덩어리 + 미세 반점.
  _dropout(pink, s, rnd, 11, p.dropout);
  _dropout(blueBase, s, rnd, 23, p.dropout);

  // 7. 블루 판 어긋남.
  final blue = Float32List(n);
  for (var y = 0; y < s; y++) {
    final sy = y - p.offsetY;
    if (sy < 0 || sy >= s) continue;
    for (var x = 0; x < s; x++) {
      final sx = x - p.offsetX;
      if (sx < 0 || sx >= s) continue;
      blue[y * s + x] = blueBase[sy * s + sx];
    }
  }

  // 8. 스티커 종이(흰 테두리) + 점선 재단선.
  final sticker = Float32List(n);
  final cut = Float32List(n);
  final cx = ox + dw / 2, cy = oy + dh / 2;
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final i = y * s + x;
      final d = distOut[i];
      sticker[i] = math.max(mask[i], _clamp01(p.border - d + 0.5));
      // 재단선: 테두리 바깥 2px 띄우고 1.5px 두께, 호 길이 기준 5 on / 3 off.
      final t = d - (p.border + 2);
      if (t > -1 && t < 2.5) {
        final w = _clamp01(t + 1) * _clamp01(2.5 - t);
        final ax = x + 0.5 - cx, ay = y + 0.5 - cy;
        final arc = math.atan2(ay, ax) * math.sqrt(ax * ax + ay * ay);
        final ph = arc - (arc / 8).floorToDouble() * 8;
        cut[i] = ph < 5 ? w : 0;
      }
    }
  }

  // 9. 합성: 흰 종이 × 핑크 × 블루(곱하기), 그레인.
  final tr = RgbaImage.blank(s, s);
  final pa = RgbaImage.blank(s, s);
  final pr = _ch(kPink, 16), pg = _ch(kPink, 8), pb = _ch(kPink, 0);
  final br = _ch(kBlue, 16), bg = _ch(kBlue, 8), bb = _ch(kBlue, 0);
  final qr = _ch(kPaper, 16), qg = _ch(kPaper, 8), qb = _ch(kPaper, 0);
  final grainAmp = p.grain * 0.16;
  for (var i = 0; i < n; i++) {
    final a = sticker[i];
    final x = i % s, y = i ~/ s;
    final g = 1 + grainAmp * (rnd.unit(x, y, 37) - 0.5);
    final pk = pink[i] * a, bl = blue[i] * a;
    var r = (1 - pk * (1 - pr)) * (1 - bl * (1 - br)) * g;
    var gg = (1 - pk * (1 - pg)) * (1 - bl * (1 - bg)) * g;
    var b = (1 - pk * (1 - pb)) * (1 - bl * (1 - bb)) * g;
    var alpha = a;

    // 재단선은 스티커 밖에만, 블루 85%.
    final c = cut[i] * (1 - a) * 0.85;
    if (c > 0) {
      final total = alpha + c * (1 - alpha);
      r = (r * alpha + br * c * (1 - alpha)) / total;
      gg = (gg * alpha + bg * c * (1 - alpha)) / total;
      b = (b * alpha + bb * c * (1 - alpha)) / total;
      alpha = total;
    }

    final o = i * 4;
    tr.pixels[o] = _u8(r);
    tr.pixels[o + 1] = _u8(gg);
    tr.pixels[o + 2] = _u8(b);
    tr.pixels[o + 3] = _u8(alpha);

    // 종이 배경 버전: 종이에도 같은 그레인.
    final pgv = 1 + grainAmp * (rnd.unit(x, y, 41) - 0.5);
    pa.pixels[o] = _u8(r * alpha + qr * pgv * (1 - alpha));
    pa.pixels[o + 1] = _u8(gg * alpha + qg * pgv * (1 - alpha));
    pa.pixels[o + 2] = _u8(b * alpha + qb * pgv * (1 - alpha));
    pa.pixels[o + 3] = 255;
  }

  return RisoOutput(tr, pa, RisoPlates(s, mask, pink, blue, sticker));
}

// ---------------------------------------------------------------- 내부

class _Box {
  _Box(this.x, this.y, this.w, this.h);
  final int x, y, w, h;
}

_Box? _alphaBounds(RgbaImage img) {
  var minX = img.width, minY = img.height, maxX = -1, maxY = -1;
  final p = img.pixels;
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      if (p[(y * img.width + x) * 4 + 3] >= 128) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return _Box(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

/// 알파 128 이상 연결 덩어리 중 가장 큰 것의 2% 미만(또는 64px 미만)은 지운다.
/// 분할 모델이 남기는 잡티가 작은 섬 스티커가 되거나 배치 크기를 흔드는 것을 막는다.
RgbaImage _dropSpecks(RgbaImage img) {
  final w = img.width, h = img.height, p = img.pixels;
  final label = Int32List(w * h); // 0 = 미방문/배경, k = 덩어리 번호(1부터)
  final sizes = <int>[0];
  final queue = Int32List(w * h);
  for (var start = 0; start < w * h; start++) {
    if (label[start] != 0 || p[start * 4 + 3] < 128) continue;
    final k = sizes.length;
    var head = 0, tail = 0, count = 0;
    queue[tail++] = start;
    label[start] = k;
    while (head < tail) {
      final i = queue[head++];
      count++;
      final x = i % w, y = i ~/ w;
      void visit(int j) {
        if (label[j] == 0 && p[j * 4 + 3] >= 128) {
          label[j] = k;
          queue[tail++] = j;
        }
      }

      if (x > 0) visit(i - 1);
      if (x < w - 1) visit(i + 1);
      if (y > 0) visit(i - w);
      if (y < h - 1) visit(i + w);
    }
    sizes.add(count);
  }
  if (sizes.length <= 2) return img; // 덩어리 0~1개
  final largest = sizes.reduce(math.max);
  final minKeep = math.max(64, (largest * 0.02).round());
  final out = Uint8List.fromList(p);
  var dropped = false;
  for (var i = 0; i < w * h; i++) {
    final k = label[i];
    if (k != 0 && sizes[k] < minKeep) {
      out[i * 4 + 3] = 0;
      dropped = true;
    }
  }
  return dropped ? RgbaImage(w, h, out) : img;
}

/// 원본 bbox를 캔버스에 배치하며 마스크와 명도(Rec.709)를 채운다.
void _place(
  RgbaImage src,
  _Box box,
  double scale,
  double ox,
  double oy,
  int s,
  Float32List mask,
  Float32List lum,
) {
  final sp = src.pixels;
  final sw = src.width, sh = src.height;
  // 하나만 샘플링하면 크게 줄일 때 계단이 생기므로 축소 비율만큼 2x2 슈퍼샘플.
  const sub = [0.25, 0.75];
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      var aSum = 0.0, lSum = 0.0;
      for (final sy in sub) {
        for (final sx in sub) {
          final fx = box.x + (x + sx - ox) / scale - 0.5;
          final fy = box.y + (y + sy - oy) / scale - 0.5;
          if (fx < -0.5 || fy < -0.5 || fx > sw - 0.5 || fy > sh - 0.5) {
            continue;
          }
          final x0 = fx.floor(), y0 = fy.floor();
          final tx = fx - x0, ty = fy - y0;
          for (var k = 0; k < 4; k++) {
            final xx = (x0 + (k & 1)).clamp(0, sw - 1);
            final yy = (y0 + (k >> 1)).clamp(0, sh - 1);
            final wgt =
                ((k & 1) == 1 ? tx : 1 - tx) * ((k >> 1) == 1 ? ty : 1 - ty);
            if (wgt == 0) continue;
            final o = (yy * sw + xx) * 4;
            final a = sp[o + 3] / 255.0;
            final l =
                (0.2126 * sp[o] + 0.7152 * sp[o + 1] + 0.0722 * sp[o + 2]) /
                255.0;
            aSum += wgt * a;
            lSum += wgt * a * l; // 프리멀티 보간: 배경색이 가장자리로 번지지 않게
          }
        }
      }
      final i = y * s + x;
      // 반투명 가장자리는 1px 안티앨리어싱만 남기고 또렷하게.
      mask[i] = _smooth(0.3, 0.7, aSum / 4);
      lum[i] = aSum > 0 ? lSum / aSum : 1;
    }
  }
}

void _autoLevels(Float32List lum, Float32List mask) {
  final hist = Int32List(256);
  var total = 0;
  for (var i = 0; i < lum.length; i++) {
    if (mask[i] >= 0.5) {
      hist[(lum[i] * 255).round().clamp(0, 255)]++;
      total++;
    }
  }
  if (total == 0) return;
  int pct(double q) {
    final target = total * q;
    var acc = 0;
    for (var v = 0; v < 256; v++) {
      acc += hist[v];
      if (acc >= target) return v;
    }
    return 255;
  }

  final lo = pct(0.02) / 255.0, hi = pct(0.98) / 255.0;
  final span = hi - lo;
  if (span < 0.05) return; // 거의 단색이면 늘리지 않음(노이즈 증폭 방지)
  for (var i = 0; i < lum.length; i++) {
    lum[i] = _clamp01((lum[i] - lo) / span);
  }
}

/// 3-4 챔퍼 거리 변환(px, 근사 유클리드).
/// inside=false: 전경(mask≥0.5)까지 거리. inside=true: 배경까지 거리.
Float32List _chamfer(Float32List mask, int s, {required bool inside}) {
  const inf = 1e9;
  final d = Float32List(s * s);
  for (var i = 0; i < d.length; i++) {
    final fg = mask[i] >= 0.5;
    d[i] = (inside ? !fg : fg) ? 0 : inf;
  }
  double at(int x, int y) =>
      (x < 0 || y < 0 || x >= s || y >= s) ? (inside ? 0 : inf) : d[y * s + x];
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final i = y * s + x;
      var v = d[i];
      v = math.min(v, at(x - 1, y) + 3);
      v = math.min(v, at(x, y - 1) + 3);
      v = math.min(v, at(x - 1, y - 1) + 4);
      v = math.min(v, at(x + 1, y - 1) + 4);
      d[i] = v;
    }
  }
  for (var y = s - 1; y >= 0; y--) {
    for (var x = s - 1; x >= 0; x--) {
      final i = y * s + x;
      var v = d[i];
      v = math.min(v, at(x + 1, y) + 3);
      v = math.min(v, at(x, y + 1) + 3);
      v = math.min(v, at(x + 1, y + 1) + 4);
      v = math.min(v, at(x - 1, y + 1) + 4);
      d[i] = v;
    }
  }
  for (var i = 0; i < d.length; i++) {
    d[i] = d[i] / 3;
  }
  return d;
}

Float32List _blur3(Float32List src, int s) {
  final out = Float32List(src.length);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      var sum = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = (y + dy).clamp(0, s - 1);
        for (var dx = -1; dx <= 1; dx++) {
          sum += src[yy * s + (x + dx).clamp(0, s - 1)];
        }
      }
      out[y * s + x] = sum / 9;
    }
  }
  return out;
}

/// Sobel 크기(0~약 1로 정규화: /4).
Float32List _sobel(Float32List l, int s) {
  final out = Float32List(l.length);
  double v(int x, int y) => l[y.clamp(0, s - 1) * s + x.clamp(0, s - 1)];
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final gx =
          -v(x - 1, y - 1) -
          2 * v(x - 1, y) -
          v(x - 1, y + 1) +
          v(x + 1, y - 1) +
          2 * v(x + 1, y) +
          v(x + 1, y + 1);
      final gy =
          -v(x - 1, y - 1) -
          2 * v(x, y - 1) -
          v(x + 1, y - 1) +
          v(x - 1, y + 1) +
          2 * v(x, y + 1) +
          v(x + 1, y + 1);
      out[y * s + x] = math.sqrt(gx * gx + gy * gy) / 4;
    }
  }
  return out;
}

class _Rot {
  _Rot(double deg)
    : c = math.cos(deg * math.pi / 180),
      s = math.sin(deg * math.pi / 180);
  final double c, s;
}

/// 회전 격자 원형 망점. 반지름 = √농도 × 셀 × 0.7, 경계 1px 안티앨리어싱.
double _dot(double x, double y, double density, double cell, _Rot r) {
  if (density <= 0) return 0;
  final u = x * r.c + y * r.s;
  final v = -x * r.s + y * r.c;
  final du = u - ((u / cell).floorToDouble() + 0.5) * cell;
  final dv = v - ((v / cell).floorToDouble() + 0.5) * cell;
  final dist = math.sqrt(du * du + dv * dv);
  final rad = math.sqrt(math.min(density, 1.0)) * cell * 0.7;
  return _clamp01(rad - dist + 0.5);
}

/// 저주파 값 노이즈가 하위 [ratio]인 곳의 잉크를 빼고, 미세 반점을 더한다.
void _dropout(Float32List ink, int s, _Hash h, int salt, double ratio) {
  if (ratio <= 0) return;
  // 값 노이즈(24px 격자) 2옥타브 → 대략 0~1.
  double noise(double x, double y) {
    double layer(double f, int k) {
      final gx = x / f, gy = y / f;
      final x0 = gx.floor(), y0 = gy.floor();
      final tx = _fade(gx - x0), ty = _fade(gy - y0);
      final a = h.unit(x0, y0, salt + k), b = h.unit(x0 + 1, y0, salt + k);
      final c = h.unit(x0, y0 + 1, salt + k),
          d = h.unit(x0 + 1, y0 + 1, salt + k);
      return (a + (b - a) * tx) +
          ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty;
    }

    return layer(24, 0) * 0.65 + layer(9, 1) * 0.35;
  }

  // 2옥타브 합은 가운데로 몰리므로 임계값을 경험적으로 맞춘다(dropout 0.04 → 약 4%, 테스트로 확인).
  final t = 0.13 + ratio * 1.6;
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final i = y * s + x;
      if (ink[i] <= 0) continue;
      final nv = noise(x.toDouble(), y.toDouble());
      var keep = _smooth(t - 0.02, t + 0.02, nv);
      if (h.unit(x, y, salt + 7) < 0.02) keep *= 0.45; // 미세 반점
      ink[i] *= keep;
    }
  }
}

double _fade(double t) => t * t * (3 - 2 * t);

/// 정수 좌표 해시 → [0,1).
class _Hash {
  _Hash(this.seed);
  final int seed;
  double unit(int x, int y, int salt) {
    var h =
        (x * 374761393 +
            y * 668265263 +
            seed * 2246822519 +
            salt * 3266489917) &
        0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
    h = h ^ (h >> 16);
    return (h & 0xFFFFFF) / 0x1000000;
  }
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _ch(int rgb, int shift) => ((rgb >> shift) & 0xFF) / 255.0;

int _u8(double v) => (v * 255).round().clamp(0, 255);

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:urienicon/h0_stats.dart';
import 'package:urienicon/imaging.dart';
import 'package:urienicon/riso/riso.dart';
import 'package:urienicon/segmenter.dart';

void main() {
  group('분할 판정', () {
    test('전경 비율 경계: 0 / 5% / 95%', () {
      expect(classifyForeground(0), SegmentFailure.noSubject);
      expect(classifyForeground(0.049), SegmentFailure.tooSmall);
      expect(classifyForeground(0.05), isNull);
      expect(classifyForeground(0.95), isNull);
      expect(classifyForeground(0.951), SegmentFailure.tooLarge);
    });

    test('모델 미설치 문구 인식', () {
      expect(
        looksModelNotReady(
          'MlKitException Waiting for the subject segmentation optional module to be downloaded',
        ),
        isTrue,
      );
      expect(looksModelNotReady('14 UNAVAILABLE'), isTrue);
      expect(
        looksModelNotReady('InputImageConverterError Bitmap data is null'),
        isFalse,
      );
    });

    test('오류·모델 미설치는 속도 통계에서 제외', () {
      expect(SegmentFailure.error.inferred, isFalse);
      expect(SegmentFailure.modelNotReady.inferred, isFalse);
      expect(SegmentFailure.tooSmall.inferred, isTrue);
      final s = H0Stats.from([
        const H0Sample(ms: 5, cold: false, inferred: false),
        const H0Sample(ms: 900, cold: false),
        const H0Sample(ms: 1100, cold: false),
      ], coldMs: 2500);
      expect(s.medianMs, 900); // 5ms 오류 표본이 섞이면 5가 됨
      expect(s.coldMs, 2500);
    });
  });

  test('앱 캐시가 아닌 경로의 사진은 절대 지우지 않는다', () async {
    final dir = await Directory.systemTemp.createTemp('urienicon_test');
    final f = File('${dir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    await deletePickedCopy(f.path);
    expect(f.existsSync(), isTrue);
    // 다른 앱 캐시 경로도 지우지 않음(존재하지 않는 경로라도 예외 없이 무시)
    await deletePickedCopy('/data/user/0/com.other.app/cache/x.jpg');
    await dir.delete(recursive: true);
  });

  test('seedFrom: 같은 픽셀 같은 시드, 다르면 다른 시드', () {
    final a = RgbaImage(2, 2, Uint8List.fromList(List.generate(16, (i) => i)));
    final b = RgbaImage(2, 2, Uint8List.fromList(List.generate(16, (i) => i)));
    final c = RgbaImage(
      2,
      2,
      Uint8List.fromList(List.generate(16, (i) => i + 1)),
    );
    expect(seedFrom(a), seedFrom(b));
    expect(seedFrom(a), isNot(seedFrom(c)));
  });

  testWidgets('PNG 인코드 왕복: 스트레이트 알파 보존, EXIF 없음', (tester) async {
    await tester.runAsync(() async {
      final src = RgbaImage.blank(8, 8);
      for (var i = 0; i < 64; i++) {
        src.pixels
          ..[i * 4] = 200
          ..[i * 4 + 1] = 40
          ..[i * 4 + 2] = 120
          ..[i * 4 + 3] = i < 32 ? 255 : 128; // 절반은 반투명
      }
      final png = await encodePng(src);
      // PNG 시그니처 + eXIf 청크 없음
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      expect(String.fromCharCodes(png).contains('eXIf'), isFalse);

      final back = await decodeToRgba(png);
      expect(back.width, 8);
      for (var i = 0; i < 64; i++) {
        final o = i * 4;
        expect(back.pixels[o + 3], src.pixels[o + 3]);
        // 반투명 픽셀은 프리멀티 반올림 오차 ±2 허용
        expect(back.pixels[o], closeTo(200, 2));
        expect(back.pixels[o + 1], closeTo(40, 2));
        expect(back.pixels[o + 2], closeTo(120, 2));
      }
    });
  });
}

import 'package:flutter/services.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

import 'imaging.dart';
import 'riso/riso.dart';

enum SegmentFailure {
  /// 전경을 못 찾음.
  noSubject('반려동물을 찾지 못했어요. 다른 사진을 골라 주세요.'),

  /// 전경이 화면의 5% 미만.
  tooSmall('반려동물이 너무 작게 나왔어요. 더 가까이 찍은 사진을 골라 주세요.'),

  /// 전경이 95% 초과(배경까지 잡힘).
  tooLarge('배경과 구분이 잘 안 돼요. 배경이 단순한 사진을 골라 주세요.'),

  /// Play 서비스가 분할 모델을 아직 내려받는 중.
  modelNotReady('분할 기능을 준비하는 중이에요. 잠시 후 다시 시도해 주세요.'),

  /// 그 밖의 오류.
  error('사진을 처리하지 못했어요. 다시 시도해 주세요.');

  const SegmentFailure(this.message);
  final String message;
}

class SegmentResult {
  SegmentResult({
    required this.mlkitMs,
    required this.cold,
    this.decodeMs = 0,
    this.cutout,
    this.cutoutPng,
    this.foregroundRatio = 0,
    this.failure,
    this.detail,
  });

  /// ML Kit 호출(채널 전송·네이티브 PNG 인코딩 포함) 시간.
  final int mlkitMs;

  /// 앱 실행 후 첫 추론이면 true(모델 적재 시간이 섞임).
  final bool cold;

  /// 전경 PNG → RGBA 디코드 시간.
  final int decodeMs;
  final RgbaImage? cutout;
  final Uint8List? cutoutPng;
  final double foregroundRatio;
  final SegmentFailure? failure;

  /// 개발용 원문 오류.
  final String? detail;

  bool get ok => failure == null;
  int get totalMs => mlkitMs + decodeMs;
}

/// ML Kit 주체 분할 래퍼. 화면 하나에서 만들고 dispose 때 [close].
class PetSegmenter {
  final _segmenter = SubjectSegmenter(
    options: SubjectSegmenterOptions(
      // 전경 비트맵(PNG, 알파=마스크)만 받는다. 신뢰도 마스크는 픽셀 수만큼
      // double이 채널로 넘어와 느리므로 끈다(설계 docs/s1-issues.md #2).
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    ),
  );

  bool _warm = false;
  bool get isWarm => _warm;

  /// 첫 추론 지연을 미리 치른다. 걸린 ms, 모델 미설치면 null.
  Future<int?> warmUp() async {
    const size = 512;
    final gray = Uint8List(size * size * 4);
    for (var i = 0; i < gray.length; i += 4) {
      gray[i] = gray[i + 1] = gray[i + 2] = 128;
      gray[i + 3] = 255;
    }
    final sw = Stopwatch()..start();
    try {
      await _segmenter.processImage(
        InputImage.fromBitmap(bitmap: gray, width: size, height: size),
      );
      _warm = true;
      return sw.elapsedMilliseconds;
    } on PlatformException {
      return null;
    }
  }

  Future<SegmentResult> segment(String path) async {
    final cold = !_warm;
    final sw = Stopwatch()..start();
    final SubjectSegmentationResult result;
    try {
      result = await _segmenter.processImage(InputImage.fromFilePath(path));
    } on PlatformException catch (e) {
      final text = '${e.code} ${e.message}';
      final notReady = RegExp(
        'download|module|unavailable',
        caseSensitive: false,
      ).hasMatch(text);
      return SegmentResult(
        mlkitMs: sw.elapsedMilliseconds,
        cold: cold,
        failure: notReady ? SegmentFailure.modelNotReady : SegmentFailure.error,
        detail: text,
      );
    }
    final mlkitMs = sw.elapsedMilliseconds;
    _warm = true;

    final png = result.foregroundBitmap;
    if (png == null || png.isEmpty) {
      return SegmentResult(
        mlkitMs: mlkitMs,
        cold: cold,
        failure: SegmentFailure.noSubject,
      );
    }
    sw
      ..reset()
      ..start();
    final cutout = await decodeToRgba(png);
    final decodeMs = sw.elapsedMilliseconds;
    final ratio = foregroundRatio(cutout);
    final failure = ratio == 0
        ? SegmentFailure.noSubject
        : ratio < 0.05
        ? SegmentFailure.tooSmall
        : ratio > 0.95
        ? SegmentFailure.tooLarge
        : null;
    return SegmentResult(
      mlkitMs: mlkitMs,
      cold: cold,
      decodeMs: decodeMs,
      cutout: cutout,
      cutoutPng: png,
      foregroundRatio: ratio,
      failure: failure,
    );
  }

  Future<void> close() => _segmenter.close();
}

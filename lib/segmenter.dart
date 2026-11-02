import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// 추론까지는 끝난 실패인가(속도 통계에 넣어도 되는가).
  bool get inferred => this != modelNotReady && this != error;
}

/// 전경 비율로 결과를 판정한다(설계 A2: 5% 미만·95% 초과면 다른 사진 안내).
@visibleForTesting
SegmentFailure? classifyForeground(double ratio) => ratio == 0
    ? SegmentFailure.noSubject
    : ratio < 0.05
    ? SegmentFailure.tooSmall
    : ratio > 0.95
    ? SegmentFailure.tooLarge
    : null;

/// 플랫폼 오류 문구가 "모델 아직 없음"인지.
@visibleForTesting
bool looksModelNotReady(String text) =>
    RegExp('download|module|unavailable', caseSensitive: false).hasMatch(text);

class SegmentResult {
  SegmentResult({
    required this.mlkitMs,
    required this.cold,
    this.decodeMs = 0,
    this.width = 0,
    this.height = 0,
    this.cutout,
    this.cutoutPng,
    this.foregroundRatio = 0,
    this.failure,
  });

  /// ML Kit 호출(채널 전송·네이티브 PNG 인코딩 포함) 시간.
  final int mlkitMs;

  /// 모델이 아직 데워지지 않은 첫 추론이면 true.
  final bool cold;

  /// 전경 PNG → RGBA 디코드 시간.
  final int decodeMs;
  final int width, height;
  final RgbaImage? cutout;
  final Uint8List? cutoutPng;
  final double foregroundRatio;
  final SegmentFailure? failure;

  bool get ok => failure == null;
  bool get inferred => failure?.inferred ?? true;
  int get totalMs => mlkitMs + decodeMs;
}

/// 앱 전체에서 하나만 쓰는 분할기. 앱 시작 때 [PetSegmenter.warmUp].
final petSegmenter = PetSegmenter();

/// ML Kit 주체 분할 래퍼.
class PetSegmenter {
  final _segmenter = SubjectSegmenter(
    options: SubjectSegmenterOptions(
      // 전경 비트맵(PNG, 알파=마스크)만 받는다. 신뢰도 마스크는 픽셀 수만큼
      // double이 채널로 넘어와 느리므로 끈다(docs/s1-issues.md #2).
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    ),
  );

  Future<int?>? _warming;
  bool _warm = false;

  /// 가장 최근 워밍업(첫 추론)에 걸린 ms.
  int? warmUpMs;

  /// 첫 추론 지연(모델 적재)을 미리 치른다. 여러 번 불러도 한 번만 돈다.
  /// 모델이 아직 없어 실패하면 다음 호출 때 다시 시도한다.
  Future<int?> warmUp() => _warming ??= _doWarmUp();

  Future<int?> _doWarmUp() async {
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
      return warmUpMs = sw.elapsedMilliseconds;
    } on PlatformException catch (e) {
      debugPrint('분할 워밍업 실패: ${e.code} ${e.message}');
      _warming = null; // 다음에 다시 시도
      return null;
    }
  }

  /// [path] 사진에서 반려동물을 오린다. 워밍업이 진행 중이면 끝날 때까지 기다린 뒤 잰다.
  Future<SegmentResult> segment(String path) async {
    await warmUp();
    final cold = !_warm;
    final sw = Stopwatch()..start();
    final SubjectSegmentationResult result;
    try {
      result = await _segmenter.processImage(InputImage.fromFilePath(path));
    } on PlatformException catch (e) {
      final text = '${e.code} ${e.message}';
      debugPrint('분할 실패: $text');
      return SegmentResult(
        mlkitMs: sw.elapsedMilliseconds,
        cold: cold,
        failure: looksModelNotReady(text)
            ? SegmentFailure.modelNotReady
            : SegmentFailure.error,
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
    return SegmentResult(
      mlkitMs: mlkitMs,
      cold: cold,
      decodeMs: decodeMs,
      width: cutout.width,
      height: cutout.height,
      cutout: cutout,
      cutoutPng: png,
      foregroundRatio: ratio,
      failure: classifyForeground(ratio),
    );
  }
}

/// image_picker가 앱 캐시에 만든 사본(축소본엔 GPS 등 EXIF가 복사됨)을 지운다.
/// 앱 캐시 경로가 아니면 절대 지우지 않는다.
Future<void> deletePickedCopy(String path) async {
  final inAppCache =
      (path.startsWith('/data/user/') || path.startsWith('/data/data/')) &&
      path.contains('/com.docky.urienicon/cache/');
  if (!inAppCache) return;
  try {
    await File(path).delete();
  } on FileSystemException catch (e) {
    debugPrint('임시 사진 삭제 실패: ${e.message}');
  }
}

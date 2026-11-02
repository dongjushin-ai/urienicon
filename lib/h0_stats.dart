/// H0(분할 품질·속도) 판정 계산. UI와 분리해 단위 테스트한다.
///
/// 기준(docs/design.md H0): 사진 중 수정 없이 OK ≥ 80%, 중급기 1장 ≤ 1.5초.
class H0Sample {
  const H0Sample({required this.ms, required this.cold, this.verdict});
  final int ms;
  final bool cold;
  final bool? verdict;
}

class H0Stats {
  H0Stats._({
    required this.count,
    required this.judged,
    required this.okCount,
    required this.medianMs,
    required this.p90Ms,
    required this.coldMs,
  });

  factory H0Stats.from(List<H0Sample> samples) {
    // 첫 추론은 모델 적재 시간이 섞이므로 속도 판정에서 뺀다.
    final warm = [
      for (final s in samples)
        if (!s.cold) s.ms,
    ]..sort();
    final cold = samples.where((s) => s.cold).map((s) => s.ms);
    final judged = samples.where((s) => s.verdict != null).length;
    final ok = samples.where((s) => s.verdict == true).length;
    return H0Stats._(
      count: samples.length,
      judged: judged,
      okCount: ok,
      medianMs: _percentile(warm, 0.5),
      p90Ms: _percentile(warm, 0.9),
      coldMs: cold.isEmpty ? null : cold.first,
    );
  }

  static const okGoal = 0.8;
  static const msGoal = 1500;

  /// 최소 표본 수. 30장 계획이지만 20장 미만이면 판정을 보류한다.
  static const minSamples = 20;

  final int count, judged, okCount;
  final int? medianMs, p90Ms, coldMs;

  double? get okRate => judged == 0 ? null : okCount / judged;

  bool? get qualityPass {
    final r = okRate;
    if (r == null || judged < count) return null; // 전부 판정해야 결론
    return r >= okGoal;
  }

  bool? get speedPass => medianMs == null ? null : medianMs! <= msGoal;

  bool? get h0Pass {
    if (count < minSamples) return null;
    final q = qualityPass, sp = speedPass;
    if (q == null || sp == null) return null;
    return q && sp;
  }

  String get verdictLabel => switch (h0Pass) {
    true => '통과',
    false => '실패 → 다듬기·촬영 가이드 강화',
    null when count < minSamples => '보류 ($count/$minSamples장)',
    null => '판정 대기',
  };

  String summaryLine(String device) =>
      'H0 ${device.isEmpty ? '' : '[$device] '}'
      'n=$count, OK ${okRate == null ? '-' : '${(okRate! * 100).toStringAsFixed(0)}%'}'
      ' ($okCount/$judged), median ${medianMs ?? '-'}ms, p90 ${p90Ms ?? '-'}ms,'
      ' cold ${coldMs ?? '-'}ms → $verdictLabel';
}

/// 최근접 순위 백분위수(정렬된 입력).
int? _percentile(List<int> sorted, double q) {
  if (sorted.isEmpty) return null;
  final rank = (q * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

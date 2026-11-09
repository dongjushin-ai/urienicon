import 'package:flutter_test/flutter_test.dart';
import 'package:urienicon/h0_stats.dart';

List<H0Sample> samples(int n, {int ok = 0, int ms = 900, int coldMs = 3000}) =>
    [
      for (var i = 0; i < n; i++)
        H0Sample(ms: i == 0 ? coldMs : ms, cold: i == 0, verdict: i < ok),
    ];

void main() {
  test('첫 추론은 속도 판정에서 제외', () {
    final s = H0Stats.from(samples(30, ok: 30));
    expect(s.coldMs, 3000);
    expect(s.medianMs, 900);
    expect(s.speedPass, isTrue);
  });

  test('OK 24/30 = 80% → 통과, 23/30 → 실패', () {
    expect(H0Stats.from(samples(30, ok: 24)).h0Pass, isTrue);
    expect(H0Stats.from(samples(30, ok: 23)).h0Pass, isFalse);
  });

  test('속도 1.5초 초과면 실패', () {
    final s = H0Stats.from(samples(30, ok: 30, ms: 1600));
    expect(s.speedPass, isFalse);
    expect(s.h0Pass, isFalse);
  });

  test('20장 미만이면 보류', () {
    final s = H0Stats.from(samples(10, ok: 10));
    expect(s.h0Pass, isNull);
    expect(s.verdictLabel, contains('보류'));
  });

  test('판정 안 한 사진이 있으면 품질 결론 보류', () {
    final list = samples(25, ok: 25)..add(const H0Sample(ms: 900, cold: false));
    expect(H0Stats.from(list).qualityPass, isNull);
  });

  test('p90 최근접 순위', () {
    final list = [
      for (var i = 1; i <= 10; i++) H0Sample(ms: i * 100, cold: false),
    ];
    expect(H0Stats.from(list).p90Ms, 900);
    expect(H0Stats.from(list).medianMs, 500);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../h0_stats.dart';
import '../main.dart';
import '../segmenter.dart';

/// H0 측정: 사진 여러 장을 차례로 분할해 시간과 OK/NG 판정을 모으고 CSV로 복사한다.
///
/// 판정 기준(설계 H0): OK ≥ 80%, 중급기 분할 ≤ 1.5초.
class H0Screen extends StatefulWidget {
  const H0Screen({super.key});

  @override
  State<H0Screen> createState() => _H0ScreenState();
}

/// 한 장 결과. 메모리를 아끼려고 RGBA 원본은 버리고 숫자와 PNG(썸네일용)만 둔다.
class _Row {
  _Row(this.index, SegmentResult r)
    : width = r.width,
      height = r.height,
      mlkitMs = r.mlkitMs,
      decodeMs = r.decodeMs,
      cold = r.cold,
      inferred = r.inferred,
      ratio = r.foregroundRatio,
      failure = r.failure,
      png = r.cutoutPng,
      verdict = r.ok ? null : false;
  final int index, width, height, mlkitMs, decodeMs;
  final bool cold, inferred;
  final double ratio;
  final SegmentFailure? failure;
  final Uint8List? png;

  /// true=OK, false=NG, null=미판정. 분할 실패는 기본 NG.
  bool? verdict;
  int get totalMs => mlkitMs + decodeMs;
}

class _H0ScreenState extends State<H0Screen> {
  final _picker = ImagePicker();
  final _device = TextEditingController();
  final _rows = <_Row>[];
  int _done = 0, _total = 0;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _device.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run() async {
    final List<XFile> files;
    try {
      files = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        limit: 30,
        requestFullMetadata: false,
      );
    } catch (e) {
      debugPrint('사진 선택 실패: $e');
      _snack('사진을 열지 못했어요. 다시 시도해 주세요.');
      return;
    }
    if (files.isEmpty) {
      _snack('사진을 고르지 않았어요.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _rows.clear();
      _done = 0;
      _total = files.length;
      _notice = null;
    });
    // 첫 추론 지연은 따로 재고, 사진들은 모두 데워진 상태에서 잰다.
    await petSegmenter.warmUp();
    // 한 장씩 순서대로(동시 실행은 시간이 섞이고 메모리가 튄다).
    for (final f in files) {
      SegmentResult r;
      try {
        r = await petSegmenter.segment(f.path);
      } catch (e) {
        debugPrint('측정 중 오류: $e');
        r = SegmentResult(
          mlkitMs: 0,
          cold: false,
          failure: SegmentFailure.error,
        );
      } finally {
        await deletePickedCopy(f.path);
      }
      if (!mounted) return;
      setState(() {
        _rows.add(_Row(_rows.length + 1, r));
        _done++;
        if (r.failure == SegmentFailure.modelNotReady) {
          _notice = SegmentFailure.modelNotReady.message;
        }
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  H0Stats get _stats => H0Stats.from([
    for (final r in _rows)
      H0Sample(
        ms: r.totalMs,
        cold: r.cold,
        inferred: r.inferred,
        verdict: r.verdict,
      ),
  ], coldMs: petSegmenter.warmUpMs);

  String _csv() {
    final device = _device.text.trim().replaceAll(',', ' ');
    final b = StringBuffer(
      'device,index,width,height,mlkit_ms,decode_ms,total_ms,cold,fg_ratio,failure,verdict\n',
    );
    for (final r in _rows) {
      b.writeln(
        [
          device,
          r.index,
          r.width,
          r.height,
          r.mlkitMs,
          r.decodeMs,
          r.totalMs,
          r.cold,
          r.ratio.toStringAsFixed(3),
          r.failure?.name ?? '',
          switch (r.verdict) {
            true => 'OK',
            false => 'NG',
            null => '',
          },
        ].join(','),
      );
    }
    return b.toString();
  }

  Future<void> _copy() async {
    final s = _stats;
    final text = '${_csv()}\n# ${s.summaryLine(_device.text.trim())}\n';
    await Clipboard.setData(ClipboardData(text: text));
    _snack('CSV와 요약을 복사했어요. docs/h0-measure.md에 붙여 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('H0 분할 측정'),
        actions: [
          IconButton(
            onPressed: _rows.isEmpty || _busy ? null : _copy,
            tooltip: 'CSV 복사',
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _device,
            decoration: const InputDecoration(
              labelText: '기기 이름 (예: Galaxy A35)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('측정할 사진 고르기 (최대 30장)'),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            Semantics(liveRegion: true, child: Text('$_done / $_total')),
          ],
          if (_notice != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _notice!,
                style: const TextStyle(color: Riso.pinkText),
              ),
            ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Summary(stats: s),
            const SizedBox(height: 8),
            Text(
              '오린 결과를 보고 그대로 스티커로 쓸 만하면 OK, 아니면 NG.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final r in _rows)
              _RowTile(row: r, onVerdict: (v) => setState(() => r.verdict = v)),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});
  final H0Stats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    Widget line(String k, String v, bool? pass) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              pass == null ? '' : (pass ? '통과' : '미달'),
              style: TextStyle(color: pass == true ? Riso.blue : Riso.pinkText),
            ),
          ),
        ],
      ),
    );
    final ok = s.okRate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            line(
              '품질 OK (판정 ${s.judged}/${s.count})',
              ok == null ? '-' : '${(ok * 100).toStringAsFixed(0)}%',
              s.qualityPass,
            ),
            line(
              '분할 중앙값',
              s.medianMs == null ? '-' : '${s.medianMs} ms',
              s.speedPass,
            ),
            line('분할 p90', s.p90Ms == null ? '-' : '${s.p90Ms} ms', null),
            line('첫 추론(워밍업)', s.coldMs == null ? '-' : '${s.coldMs} ms', null),
            const Divider(),
            line('H0 판정', s.verdictLabel, s.h0Pass),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.onVerdict});
  final _Row row;
  final ValueChanged<bool?> onVerdict;

  @override
  Widget build(BuildContext context) {
    final png = row.png;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 72,
            child: ColoredBox(
              color: const Color(0xFF26262E),
              child: png == null
                  ? Icon(
                      Icons.block,
                      color: Colors.white70,
                      semanticLabel: '${row.index}번 오리기 실패',
                    )
                  : Semantics(
                      label: '${row.index}번 오린 결과',
                      image: true,
                      child: Image.memory(png, cacheWidth: 144),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '#${row.index}  ${row.totalMs}ms\n'
              '전경 ${(row.ratio * 100).toStringAsFixed(0)}%'
              '${row.failure == null ? '' : ' · ${row.failure!.name}'}',
            ),
          ),
          Semantics(
            label: '${row.index}번 판정',
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('OK')),
                ButtonSegment(value: false, label: Text('NG')),
              ],
              selected: {?row.verdict},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (v) => onVerdict(v.isEmpty ? null : v.first),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../imaging.dart';
import '../main.dart';
import '../riso/riso.dart';
import '../segmenter.dart';

/// S1 결과물: 사진 1장 → 분할 → 리소 변환 → PNG 저장. 단계별 시간을 보여 준다.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _Timing {
  int? mlkit, decode, riso, encode;
  bool cold = false;
}

class _SpikeScreenState extends State<SpikeScreen> {
  final _picker = ImagePicker();

  bool _busy = false;
  String? _status;
  String? _warning;
  RgbaImage? _cutout;
  RisoParams _params = const RisoParams();
  Uint8List? _paperPng, _transparentPng;
  final _t = _Timing();

  @override
  void initState() {
    super.initState();
    // 앱 시작 때 시작한 워밍업이 실패했으면(모델 받는 중) 여기서 다시 시도.
    petSegmenter.warmUp();
    _recoverLostPick();
  }

  /// 저사양 기기에서 Photo Picker가 열린 사이 앱이 종료되면 고른 사진을 되살린다.
  Future<void> _recoverLostPick() async {
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file;
      if (file != null && mounted) await _process(file);
    } catch (e) {
      debugPrint('lost data 복구 실패: $e');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick() async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        requestFullMetadata: false,
      );
    } catch (e) {
      debugPrint('사진 선택 실패: $e');
      _snack('사진을 열지 못했어요. 다시 시도해 주세요.');
      return;
    }
    if (file == null) {
      _snack('사진을 고르지 않았어요.');
      return;
    }
    await _process(file);
  }

  Future<void> _process(XFile file) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = '오려내는 중…';
      _warning = null;
      _paperPng = _transparentPng = null;
      _cutout = null;
    });
    try {
      final size = await readImageSize(await file.readAsBytes());
      final longest = size.longestSide;
      final warning = longest < 512
          ? '사진이 작아요(${longest.round()}px). 결과가 흐릴 수 있어요.'
          : null;

      final r = await petSegmenter.segment(file.path);
      if (!mounted) return;
      _t
        ..mlkit = r.mlkitMs
        ..decode = r.decodeMs
        ..cold = r.cold;
      if (!r.ok) {
        setState(() {
          _busy = false;
          _status = r.failure!.message;
          _warning = warning;
        });
        return;
      }
      _cutout = r.cutout;
      _params = _params.copyWith(seed: seedFrom(r.cutout!));
      setState(() => _warning = warning);
      await _render();
    } catch (e, st) {
      debugPrint('처리 실패: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = SegmentFailure.error.message;
      });
    } finally {
      await deletePickedCopy(file.path);
    }
  }

  Future<void> _render() async {
    final cutout = _cutout;
    if (cutout == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = '리소 판 만드는 중…';
    });
    try {
      final params = _params;
      final sw = Stopwatch()..start();
      // 무거운 픽셀 연산은 UI 스레드 밖에서(State를 붙잡지 않게 최상위 함수로).
      final out = await compute(_risoJob, (cutout, params));
      _t.riso = sw.elapsedMilliseconds;
      sw
        ..reset()
        ..start();
      final paper = await encodePng(out.paper);
      final transparent = await encodePng(out.transparent);
      _t.encode = sw.elapsedMilliseconds;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _paperPng = paper;
        _transparentPng = transparent;
      });
    } catch (e, st) {
      debugPrint('리소 변환 실패: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '스티커로 바꾸지 못했어요. 다른 사진을 골라 주세요.';
      });
    }
  }

  Future<void> _save() async {
    final paper = _paperPng, transparent = _transparentPng;
    if (paper == null || transparent == null) return;
    var saved = 0;
    try {
      // Android 10 이하만 저장 권한이 필요하다(매니페스트 maxSdk 29).
      if (!await Gal.hasAccess(toAlbum: true) &&
          !await Gal.requestAccess(toAlbum: true)) {
        _snack('저장 권한이 없어 갤러리에 저장하지 못했어요.');
        return;
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (final (png, kind) in [
        (paper, 'paper'),
        (transparent, 'transparent'),
      ]) {
        await Gal.putImageBytes(
          png,
          album: '우리애콘',
          name: 'urienicon_${stamp}_$kind',
        );
        saved++;
      }
      _snack('갤러리 "우리애콘" 앨범에 2장 저장했어요.');
    } on GalException catch (e) {
      final reason = switch (e.type) {
        GalExceptionType.accessDenied => '갤러리 접근이 거부됐어요.',
        GalExceptionType.notEnoughSpace => '저장 공간이 부족해요.',
        GalExceptionType.notSupportedFormat => '지원하지 않는 형식이에요.',
        GalExceptionType.unexpected => '알 수 없는 오류가 났어요.',
      };
      _snack(saved == 0 ? '저장 실패: $reason' : '1장만 저장됐어요(종이 배경). $reason');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _paperPng != null;
    return Scaffold(
      appBar: AppBar(title: const Text('사진 1장 → 리소 스티커')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('반려동물 사진 고르기'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _status!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (_warning != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _warning!,
                style: const TextStyle(color: Riso.pinkText),
              ),
            ),
          ],
          if (hasResult) ...[
            const SizedBox(height: 16),
            _Preview(paper: _paperPng!, transparent: _transparentPng!),
            const SizedBox(height: 12),
            _TimingTable(t: _t),
            _Tuning(
              params: _params,
              enabled: !_busy,
              onChanged: (p) => setState(() => _params = p),
              onChangeEnd: (p) {
                _params = p;
                _render();
              },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.download_outlined),
              label: const Text('갤러리에 저장 (종이 배경 + 투명)'),
            ),
          ],
        ],
      ),
    );
  }
}

RisoOutput _risoJob((RgbaImage, RisoParams) job) => renderRiso(job.$1, job.$2);

class _Preview extends StatelessWidget {
  const _Preview({required this.paper, required this.transparent});
  final Uint8List paper, transparent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: '리소 스티커 미리보기, 종이 배경',
            image: true,
            child: Image.memory(paper, gaplessPlayback: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // 다크 모드 채팅방에서 어떻게 보이는지 확인용.
          child: ColoredBox(
            color: const Color(0xFF26262E),
            child: Semantics(
              label: '리소 스티커 미리보기, 투명 배경을 어두운 바탕에 표시',
              image: true,
              child: Image.memory(transparent, gaplessPlayback: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimingTable extends StatelessWidget {
  const _TimingTable({required this.t});
  final _Timing t;

  @override
  Widget build(BuildContext context) {
    final seg = (t.mlkit ?? 0) + (t.decode ?? 0);
    TableRow row(String k, int? ms, [int? goal]) {
      final over = goal != null && ms != null && ms > goal;
      return TableRow(
        children: [
          Padding(padding: const EdgeInsets.all(4), child: Text(k)),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              ms == null ? '-' : '$ms ms',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: over ? Riso.pinkText : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            // 색만으로 구분하지 않도록 글자로도 표시.
            child: Text(
              goal == null ? '' : (over ? '초과 (≤ $goal)' : '≤ $goal'),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }

    return Table(
      columnWidths: const {0: FlexColumnWidth(2)},
      children: [
        row('분할 ML Kit${t.cold ? ' (첫 추론)' : ''}', t.mlkit),
        row('전경 디코드', t.decode),
        row('분할 합계', seg, 1500),
        row('리소 변환 (CPU)', t.riso, 1000),
        row('PNG 2장 인코드', t.encode),
      ],
    );
  }
}

class _Tuning extends StatelessWidget {
  const _Tuning({
    required this.params,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });
  final RisoParams params;
  final bool enabled;
  final ValueChanged<RisoParams> onChanged, onChangeEnd;

  @override
  Widget build(BuildContext context) {
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      RisoParams Function(double) apply, {
      int? divisions,
      String unit = 'px',
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label  ${value.toStringAsFixed(divisions == null ? 2 : 0)}$unit',
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(divisions == null ? 2 : 0),
            semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(1)}',
            onChanged: enabled ? (v) => onChanged(apply(v)) : null,
            onChangeEnd: enabled ? (v) => onChangeEnd(apply(v)) : null,
          ),
        ],
      );
    }

    return ExpansionTile(
      title: const Text('판 조정 (튜닝용)'),
      tilePadding: EdgeInsets.zero,
      children: [
        slider(
          '흰 테두리',
          params.border,
          0,
          16,
          (v) => params.copyWith(border: v.roundToDouble()),
          divisions: 16,
        ),
        slider(
          '어긋남 X',
          params.offsetX.toDouble(),
          0,
          10,
          (v) => params.copyWith(offsetX: v.round()),
          divisions: 10,
        ),
        slider(
          '어긋남 Y',
          params.offsetY.toDouble(),
          0,
          10,
          (v) => params.copyWith(offsetY: v.round()),
          divisions: 10,
        ),
        slider(
          '망점 셀',
          params.cell,
          4,
          10,
          (v) => params.copyWith(cell: v.roundToDouble()),
          divisions: 6,
        ),
        slider(
          '그레인',
          params.grain,
          0,
          1,
          (v) => params.copyWith(grain: v),
          unit: '',
        ),
      ],
    );
  }
}

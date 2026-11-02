// AOT 벤치마크: dart compile exe tool/riso_bench.dart -o riso_bench && ./riso_bench <오린 PNG>
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:urienicon/riso/riso.dart';

void main(List<String> args) {
  final src = img
      .decodePng(File(args[0]).readAsBytesSync())!
      .convert(numChannels: 4, format: img.Format.uint8);
  final cutout = RgbaImage(
    src.width,
    src.height,
    src.getBytes(order: img.ChannelOrder.rgba),
  );
  final times = <int>[];
  for (var i = 0; i < 12; i++) {
    final sw = Stopwatch()..start();
    renderRiso(cutout, RisoParams(seed: i));
    times.add(sw.elapsedMilliseconds);
  }
  final warm = times.skip(2).toList()..sort();
  stdout.writeln(
    '입력 ${src.width}x${src.height}, 첫 ${times.first}ms, 중앙값 ${warm[warm.length ~/ 2]}ms',
  );
}

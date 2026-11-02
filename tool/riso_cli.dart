// 폰 없이 리소 변환을 확인하는 도구.
//
//   dart run tool/riso_cli.dart <오린 PNG> <출력 폴더> [seed]
//
// 배경이 투명한 PNG(누끼)를 받아 투명/종이 배경 스티커 PNG 2장과 판별 미리보기를 쓴다.
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:urienicon/riso/riso.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('사용법: dart run tool/riso_cli.dart <오린 PNG> <출력 폴더> [seed]');
    exitCode = 64;
    return;
  }
  final src = img.decodePng(File(args[0]).readAsBytesSync());
  if (src == null) {
    stderr.writeln('PNG를 읽지 못함: ${args[0]}');
    exitCode = 65;
    return;
  }
  final rgba = src.convert(numChannels: 4, format: img.Format.uint8);
  final cutout = RgbaImage(
    rgba.width,
    rgba.height,
    rgba.getBytes(order: img.ChannelOrder.rgba),
  );
  final seed = args.length > 2 ? int.parse(args[2]) : 1;

  final sw = Stopwatch()..start();
  final out = renderRiso(cutout, RisoParams(seed: seed));
  sw.stop();

  final dir = Directory(args[1])..createSync(recursive: true);
  void save(String name, RgbaImage im) {
    final o = img.Image.fromBytes(
      width: im.width,
      height: im.height,
      bytes: im.pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    File('${dir.path}/$name').writeAsBytesSync(img.encodePng(o));
  }

  save('sticker_transparent.png', out.transparent);
  save('sticker_paper.png', out.paper);
  stdout.writeln(
    '전경 비율 ${(foregroundRatio(cutout) * 100).toStringAsFixed(1)}%, '
    '변환 ${sw.elapsedMilliseconds}ms(JIT, 기기와 다름) → ${dir.path}',
  );
}

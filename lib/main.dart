import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'screens/h0_screen.dart';
import 'screens/spike_screen.dart';
import 'segmenter.dart';

void main() {
  // Android 15 이하도 시스템 Photo Picker 사용(사진 권한 0개). 16+는 항상 Photo Picker.
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;
  runApp(const UrieniconApp());
  // 설계 A2: 앱 시작 때 더미 추론으로 첫 추론 지연을 미리 치른다(결과는 기다리지 않음).
  petSegmenter.warmUp();
}

/// docs/style.md 팔레트.
abstract final class Riso {
  static const paper = Color(0xFFF3EDE0);
  static const pink = Color(0xFFFF4FA3);
  static const blue = Color(0xFF2F4FB8);
  static const yellow = Color(0xFFFFD400);

  /// 종이색 위 글자용 진한 핑크(대비 5.8:1, WCAG AA). 형광 핑크는 글자로 쓰면 2.6:1.
  static const pinkText = Color(0xFFB0125F);
}

class UrieniconApp extends StatelessWidget {
  const UrieniconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우리애콘',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Riso.blue,
          primary: Riso.blue,
          secondary: Riso.pink,
          surface: Riso.paper,
        ),
        scaffoldBackgroundColor: Riso.paper,
      ),
      home: const SpikeHome(),
    );
  }
}

/// S1 스파이크 진입 화면.
class SpikeHome extends StatelessWidget {
  const SpikeHome({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                '우리애콘',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Riso.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text('S1 스파이크', textAlign: TextAlign.center),
              const Spacer(),
              FilledButton(
                onPressed: () => open(const SpikeScreen()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('사진 1장 → 리소 스티커'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => open(const H0Screen()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('H0 분할 측정 (여러 장)'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

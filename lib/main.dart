import 'package:flutter/material.dart';

void main() {
  runApp(const UrieniconApp());
}

/// docs/style.md 팔레트.
abstract final class Riso {
  static const paper = Color(0xFFF3EDE0);
  static const pink = Color(0xFFFF4FA3);
  static const blue = Color(0xFF2F4FB8);
  static const yellow = Color(0xFFFFD400);
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

/// S1 스파이크 진입 화면. 사진 1장 → 분할 → 리소 변환 → PNG 저장은 S1 이슈에서 채운다.
class SpikeHome extends StatelessWidget {
  const SpikeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          '우리애콘',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Riso.blue,
          ),
        ),
      ),
    );
  }
}

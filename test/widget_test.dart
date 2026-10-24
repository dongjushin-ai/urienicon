import 'package:flutter_test/flutter_test.dart';
import 'package:urienicon/main.dart';

void main() {
  testWidgets('앱이 뜨고 제목이 보인다', (tester) async {
    await tester.pumpWidget(const UrieniconApp());
    expect(find.text('우리애콘'), findsOneWidget);
  });
}

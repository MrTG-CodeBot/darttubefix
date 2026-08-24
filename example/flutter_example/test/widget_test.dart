import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_example/main.dart';

void main() {
  testWidgets('DartTubeFixApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DartTubeFixApp());
    expect(find.text('darttubefix Tester'), findsOneWidget);
  });
}

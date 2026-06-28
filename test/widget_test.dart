import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:viewstage_phone/main.dart';
import 'package:viewstage_phone/services/connection_manager.dart';

void main() {
  testWidgets('App should show connect screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ConnectionManager(),
        child: const MyApp(),
      ),
    );

    expect(find.text('连接 ViewStage'), findsOneWidget);
  });
}

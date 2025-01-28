// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_files/main.dart';

void main() {
  testWidgets('Shared files app test', (WidgetTester tester) async {
    // アプリをビルド
    await tester.pumpWidget(const MyApp());

    // 非同期処理の完了を待機
    await tester.pumpAndSettle();

    // 初期状態では「共有されたファイルはありません」が表示されていることを確認
    expect(find.text('共有されたファイルはありません'), findsOneWidget);

    // AppBarのタイトルを確認
    expect(find.text('共有ファイル受信'), findsOneWidget);
  });
}

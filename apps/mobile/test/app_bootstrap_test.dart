import 'package:coffee_management_mobile/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('application shell mounts without feature dependencies', (
    tester,
  ) async {
    await tester.pumpWidget(const CoffeeManagementApp());

    expect(find.text('Coffee Management System'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:coffee_management_mobile/shared/theme/app_theme.dart';
import 'package:coffee_management_mobile/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTextField', () {
    testWidgets('renders label, hint, and helper text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppTextField(
              label: 'Username',
              hintText: 'Enter username',
              helperText: 'Must be unique',
            ),
          ),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Must be unique'), findsOneWidget);
    });

    testWidgets('renders error text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppTextField(
              label: 'Password',
              errorText: 'Password cannot be empty',
            ),
          ),
        ),
      );

      expect(find.text('Password cannot be empty'), findsOneWidget);
    });

    testWidgets('captures user text input via onChanged', (tester) async {
      String changedValue = '';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: Scaffold(
            body: AppTextField(
              label: 'Notes',
              onChanged: (val) => changedValue = val,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Extra foam');
      expect(changedValue, equals('Extra foam'));
    });

    testWidgets('renders prefix and suffix widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppTextField(
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.clear),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('respects enabled and obscureText flags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildLightTheme(),
          home: const Scaffold(
            body: AppTextField(enabled: false, obscureText: true),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
      expect(textField.obscureText, isTrue);
    });
  });
}

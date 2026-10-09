import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/theme/app_theme.dart';
import 'package:expense_tracker/widgets/category_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a typed emoji becomes the symbol (only the last one typed)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    ExpenseCategory? saved;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCategorySheet(
            context,
            title: 'New category',
            buttonLabel: 'Create',
            nameError: (_) => null,
            onSaved: (category) async => saved = category,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Cricket');
    await tester.enterText(find.byType(TextField).last, '🎾🏏');
    await tester.pump();
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Cricket');
    expect(saved?.emoji, '🏏');
  });
}

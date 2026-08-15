import 'package:carepath_india/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact mobile upload screen has no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const CarePathApp());
    expect(
      find.text('Recovery instructions,\nwithout the overwhelm.'),
      findsOneWidget,
    );
    expect(find.text('Create my recovery plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

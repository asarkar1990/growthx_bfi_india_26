import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carepath_india/main.dart';
import 'package:carepath_india/src/care_plan_api.dart';
import 'package:carepath_india/src/care_plan_cubit.dart';
import 'package:carepath_india/src/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleJson = File(
    'assets/samples/sample_plan_en.json',
  ).readAsStringSync();
  final sampleMap = jsonDecode(sampleJson) as Map<String, dynamic>;
  final defaultMockClient = MockClient((request) async {
    return http.Response(
      jsonEncode({
        'plan': sampleMap,
        'meta': {'isSample': true},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CarePlanCubit createTestCubit() => CarePlanCubit(
    api: CarePlanApi(
      httpClient: defaultMockClient,
      baseUrl: 'http://127.0.0.1:8000',
    ),
    storage: CarePlanStorage(),
  );

  testWidgets('compact mobile upload screen has no overflow and bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(CarePathApp(cubit: createTestCubit()));
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('CarePath'), findsOneWidget);
    expect(find.text('Get Well Soon'), findsOneWidget);
    expect(find.text('Add discharge summary'), findsOneWidget);
    expect(find.text('Upload discharge summary'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Summaries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan controls appear after selecting a document', (
    tester,
  ) async {
    final cubit = createTestCubit();
    await tester.pumpWidget(CarePathApp(cubit: cubit));

    cubit.useSample();
    await tester.pump();

    expect(find.text('Synthetic discharge summary.pdf'), findsOneWidget);
    expect(find.text('Create recovery plan'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    cubit.setLanguage('kn');
    await tester.pump();

    expect(find.text('ಕನ್ನಡ'), findsOneWidget);
  });

  testWidgets(
    'creates plan, confirms and activates plan screen with date chips',
    (tester) async {
      final cubit = createTestCubit();
      await tester.pumpWidget(CarePathApp(cubit: cubit));

      cubit.useSample();
      unawaited(cubit.createPlan(stageDelay: const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 50));

      // Confirmation view is displayed
      expect(find.text('Confirm & Save Plan'), findsOneWidget);
      expect(find.text('Confirm & Activate Recovery Plan'), findsOneWidget);
      expect(find.text('Mr. Arindam Sarkar'), findsOneWidget);

      // Confirm and save
      await tester.ensureVisible(find.text('Confirm & Activate Recovery Plan'));
      await tester.tap(find.text('Confirm & Activate Recovery Plan'));
      await tester.pump(const Duration(milliseconds: 50));

      // Full plan screen is displayed
      expect(find.text('Mr. Arindam Sarkar’s Recovery Plan'), findsOneWidget);
      expect(find.text('Fri, 17 Apr • Day 1'), findsOneWidget);
      expect(find.text('Friday, 17 April • Day 1 Routine'), findsOneWidget);
      expect(find.text('Doctor’s Discharge Summary'), findsOneWidget);
      expect(find.text('MORNING'), findsOneWidget);
      expect(find.text('Active Plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bottom bar navigates to history and displays active plan badge',
    (tester) async {
      final cubit = createTestCubit();
      await tester.pumpWidget(CarePathApp(cubit: cubit));

      // First switch to history tab (empty)
      await tester.tap(find.text('Summaries'));
      await tester.pump();
      expect(find.text('No saved summaries yet'), findsOneWidget);

      // Create and save a plan
      await tester.tap(find.text('Home'));
      await tester.pump();
      cubit.useSample();
      unawaited(cubit.createPlan(stageDelay: const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(find.text('Confirm & Activate Recovery Plan'));
      await tester.tap(find.text('Confirm & Activate Recovery Plan'));
      await tester.pump(const Duration(milliseconds: 50));

      // Now switch to history tab
      await tester.tap(find.text('Summaries'));
      await tester.pump();

      expect(find.text('Manage Summaries'), findsOneWidget);
      expect(find.text('1 saved discharge record'), findsOneWidget);
      expect(find.text('ACTIVE PLAN'), findsOneWidget);
      expect(find.text('View Plan'), findsOneWidget);
    },
  );

  testWidgets(
    'in-app medication reminder alert renders real medicine name and handles mark as taken',
    (tester) async {
      final cubit = createTestCubit();
      await tester.pumpWidget(CarePathApp(cubit: cubit));

      // Create and save plan
      cubit.useSample();
      unawaited(cubit.createPlan(stageDelay: const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(find.text('Confirm & Activate Recovery Plan'));
      await tester.tap(find.text('Confirm & Activate Recovery Plan'));
      await tester.pumpAndSettle();

      // Open Reminders Setup
      cubit.showReminders();
      await tester.pumpAndSettle();

      expect(find.text('Medication reminders'), findsOneWidget);
      expect(find.text('TAXIM-O'), findsOneWidget);

      // Tap Test In-App Alert on the first medicine
      final testAlertButton = find.text('Test In-App Alert').first;
      await tester.tap(testAlertButton);
      await tester.pumpAndSettle();

      // Alert Dialog is shown with full details and real medicine name
      expect(find.text('MEDICATION REMINDER'), findsOneWidget);
      expect(find.text('TAXIM-O'), findsNWidgets(2)); // in list and dialog
      expect(find.text('Mark as Taken'), findsOneWidget);
      expect(find.text('Snooze'), findsOneWidget);

      // Tap Mark as Taken
      await tester.tap(find.text('Mark as Taken'));
      await tester.pumpAndSettle();

      expect(find.text('Taken: TAXIM-O recorded.'), findsOneWidget);
    },
  );
}

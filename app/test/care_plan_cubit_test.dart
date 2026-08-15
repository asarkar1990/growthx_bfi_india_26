import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:carepath_india/src/care_plan_api.dart';
import 'package:carepath_india/src/care_plan_cubit.dart';
import 'package:carepath_india/src/storage_service.dart';
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

  blocTest<CarePlanCubit, CarePlanState>(
    'requires a file before processing',
    build: () => CarePlanCubit(
      api: CarePlanApi(
        httpClient: defaultMockClient,
        baseUrl: 'http://127.0.0.1:8000',
      ),
      storage: CarePlanStorage(),
    ),
    act: (c) => c.createPlan(stageDelay: Duration.zero),
    verify: (c) => expect(c.state.error, isNotNull),
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'sample reaches confirming phase and can be confirmed and saved',
    build: () => CarePlanCubit(
      api: CarePlanApi(
        httpClient: defaultMockClient,
        baseUrl: 'http://127.0.0.1:8000',
      ),
      storage: CarePlanStorage(),
    ),
    act: (c) async {
      c.useSample();
      await c.createPlan(stageDelay: Duration.zero);
      expect(c.state.phase, CarePlanPhase.confirming);
      expect(c.state.pendingPlan?.patientName, 'Mr. Arindam Sarkar');

      await c.confirmAndSavePendingPlan();
    },
    verify: (c) {
      expect(c.state.phase, CarePlanPhase.ready);
      expect(c.state.plan?.patientName, 'Mr. Arindam Sarkar');
      expect(c.state.savedSummaries, hasLength(1));
      expect(c.state.activeSummaryId, isNotNull);
    },
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'discarding pending plan clears pending state',
    build: () => CarePlanCubit(
      api: CarePlanApi(
        httpClient: defaultMockClient,
        baseUrl: 'http://127.0.0.1:8000',
      ),
      storage: CarePlanStorage(),
    ),
    act: (c) async {
      c.useSample();
      await c.createPlan(stageDelay: Duration.zero);
      expect(c.state.phase, CarePlanPhase.confirming);

      c.discardPendingPlan();
    },
    verify: (c) {
      expect(c.state.phase, CarePlanPhase.upload);
      expect(c.state.pendingPlan, isNull);
    },
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'uploading real file calls API and surfaces confirmation',
    build: () {
      return CarePlanCubit(
        api: CarePlanApi(
          httpClient: defaultMockClient,
          baseUrl: 'http://127.0.0.1:8000',
        ),
        storage: CarePlanStorage(),
      );
    },
    act: (c) async {
      c.selectFile('summary.pdf', bytes: Uint8List.fromList([10, 20, 30]));
      await c.createPlan(stageDelay: Duration.zero);
      await c.confirmAndSavePendingPlan();
    },
    verify: (c) {
      expect(c.state.phase, CarePlanPhase.ready);
      expect(c.state.plan?.patientName, 'Mr. Arindam Sarkar');
    },
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'uploading real file surfaces backend API error envelope in failure phase',
    build: () {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'UNREADABLE_DOCUMENT',
              'message':
                  'We could not read enough of this document. Upload a clearer image or try the sample.',
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });
      return CarePlanCubit(
        api: CarePlanApi(
          httpClient: mockClient,
          baseUrl: 'http://127.0.0.1:8000',
        ),
        storage: CarePlanStorage(),
      );
    },
    act: (c) async {
      c.selectFile('blurry.jpg', bytes: Uint8List.fromList([1, 2, 3]));
      await c.createPlan(stageDelay: Duration.zero);
    },
    verify: (c) {
      expect(c.state.phase, CarePlanPhase.failure);
      expect(
        c.state.error,
        'We could not read enough of this document. Upload a clearer image or try the sample.',
      );
    },
  );
}

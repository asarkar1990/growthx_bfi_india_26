import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:carepath_india/src/care_plan_api.dart';
import 'package:carepath_india/src/care_plan_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  blocTest<CarePlanCubit, CarePlanState>(
    'requires a file before processing',
    build: () => CarePlanCubit(
      fixtureLoader: (_) =>
          File('assets/samples/sample_plan_en.json').readAsString(),
    ),
    act: (c) => c.createPlan(stageDelay: Duration.zero),
    verify: (c) => expect(c.state.error, isNotNull),
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'sample reaches a validated ready state',
    build: () => CarePlanCubit(
      fixtureLoader: (_) =>
          File('assets/samples/sample_plan_en.json').readAsString(),
    ),
    act: (c) async {
      c.useSample();
      await c.createPlan(stageDelay: Duration.zero);
    },
    verify: (c) {
      expect(c.state.phase, CarePlanPhase.ready);
      expect(c.state.plan?.patientName, 'Mr. Arindam Sarkar');
    },
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'updating API base URL normalizes and stores new URL',
    build: () => CarePlanCubit(
      api: CarePlanApi(
        httpClient: MockClient(
          (_) async => http.Response('{"status":"ok"}', 200),
        ),
        baseUrl: 'http://127.0.0.1:8000',
      ),
    ),
    act: (c) => c.setApiBaseUrl('http://192.168.1.10:8000/'),
    verify: (c) {
      expect(c.state.apiBaseUrl, 'http://192.168.1.10:8000');
    },
  );

  blocTest<CarePlanCubit, CarePlanState>(
    'uploading real file calls API and surfaces plan',
    build: () {
      final sampleJson = File(
        'assets/samples/sample_plan_en.json',
      ).readAsStringSync();
      final sampleMap = jsonDecode(sampleJson) as Map<String, dynamic>;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'plan': sampleMap,
            'meta': {'isSample': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      return CarePlanCubit(
        api: CarePlanApi(
          httpClient: mockClient,
          baseUrl: 'http://127.0.0.1:8000',
        ),
      );
    },
    act: (c) async {
      c.selectFile('summary.pdf', bytes: Uint8List.fromList([10, 20, 30]));
      await c.createPlan(stageDelay: Duration.zero);
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

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:carepath_india/src/care_plan_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(c.state.plan?.patientName, 'Aarav');
    },
  );
}

import 'dart:convert';

import 'package:carepath_india/src/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('sample fixture parses strictly', () async {
    final json =
        jsonDecode(
              await rootBundle.loadString('assets/samples/sample_plan_en.json'),
            )
            as Map<String, dynamic>;
    final plan = DischargePlan.fromJson(json);
    expect(plan.items, hasLength(8));
    expect(plan.issues, hasLength(1));
  });
  test('reminder eligibility excludes uncertain and anytime', () {
    const confirmed = PlanItem(
      id: '1',
      title: 'Task',
      instruction: 'Do it',
      timing: PlanTiming.morning,
      days: [1],
      evidence: 'source',
      status: ItemStatus.confirmedFromSource,
    );
    const uncertain = PlanItem(
      id: '2',
      title: 'Task',
      instruction: 'Ask',
      timing: PlanTiming.morning,
      days: [1],
      evidence: 'source',
      status: ItemStatus.needsConfirmation,
    );
    const anytime = PlanItem(
      id: '3',
      title: 'Task',
      instruction: 'As needed',
      timing: PlanTiming.anytime,
      days: [1],
      evidence: 'source',
      status: ItemStatus.confirmedFromSource,
    );
    expect(confirmed.reminderEligible, isTrue);
    expect(uncertain.reminderEligible, isFalse);
    expect(anytime.reminderEligible, isFalse);
  });
  test(
    'unknown safety status fails closed',
    () => expect(() => parseStatus('probably'), throwsFormatException),
  );
}

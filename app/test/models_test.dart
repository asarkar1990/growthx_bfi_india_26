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
    expect(plan.dischargeDate, '2026-04-17');
    expect(plan.dayChipLabel(1), 'Fri, 17 Apr • Day 1');
    expect(plan.dayFullHeading(1), 'Friday, 17 April • Day 1 Routine');
    expect(plan.dayChipLabel(4), 'Mon, 20 Apr • Day 4');
    expect(plan.items.first.effectiveTimings, [
      PlanTiming.morning,
      PlanTiming.evening,
    ]);
    expect(plan.followUps.first.type, 'appointment');
    expect(plan.followUps.first.date, '2026-04-21');
    expect(plan.followUps.first.location, 'Internal Medicine OPD');
  });

  test(
    'next action chooses the earliest medication or hospital visit',
    () async {
      final json =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/samples/sample_plan_en.json',
                ),
              )
              as Map<String, dynamic>;
      final plan = DischargePlan.fromJson(json);

      final upcoming = plan.nextActions(DateTime(2026, 4, 17, 7));
      expect(upcoming, hasLength(5));
      for (var index = 1; index < upcoming.length; index++) {
        expect(
          upcoming[index].when.isBefore(upcoming[index - 1].when),
          isFalse,
        );
      }
      expect(
        upcoming.every((action) => action.type == NextActionType.medication),
        isTrue,
      );

      final first = plan.nextAction(DateTime(2026, 4, 17, 7));
      expect(first?.type, NextActionType.medication);
      expect(first?.when, DateTime(2026, 4, 17, 8));

      final visit = plan.nextAction(DateTime(2026, 4, 21, 8, 30));
      expect(visit?.type, NextActionType.hospitalVisit);
      expect(visit?.title, 'Internal Medicine OPD Follow-up');
      expect(visit?.when, DateTime(2026, 4, 21));
    },
  );

  test('next action ignores as-needed items after the schedule ends', () async {
    final json =
        jsonDecode(
              await rootBundle.loadString('assets/samples/sample_plan_en.json'),
            )
            as Map<String, dynamic>;
    final plan = DischargePlan.fromJson(json);

    expect(plan.nextAction(DateTime(2026, 4, 22)), isNull);
  });
  test('Kannada plans are accepted by the schema', () async {
    final json =
        jsonDecode(
              await rootBundle.loadString('assets/samples/sample_plan_en.json'),
            )
            as Map<String, dynamic>;
    json['outputLanguage'] = 'kn';

    expect(DischargePlan.fromJson(json).language, 'kn');
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

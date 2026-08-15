import 'dart:convert';
import 'dart:io';

import 'package:carepath_india/src/models.dart';
import 'package:carepath_india/src/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CarePlanStorage storage;
  late DischargePlan samplePlan;
  late Map<String, dynamic> sampleMap;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = CarePlanStorage();
    final sampleJson = File(
      'assets/samples/sample_plan_en.json',
    ).readAsStringSync();
    sampleMap = jsonDecode(sampleJson) as Map<String, dynamic>;
    samplePlan = DischargePlan.fromJson(sampleMap);
  });

  test('saving plan persists and marks as active', () async {
    final entry = await storage.saveSummary(samplePlan, rawJson: sampleMap);
    expect(entry.isActive, isTrue);
    expect(entry.patientName, 'Mr. Arindam Sarkar');

    final loaded = await storage.loadSummaries();
    expect(loaded, hasLength(1));
    expect(loaded.first.id, entry.id);
    expect(loaded.first.isActive, isTrue);
    expect(loaded.first.plan.patientName, 'Mr. Arindam Sarkar');
  });

  test('getActiveSummary returns currently active plan', () async {
    expect(await storage.getActiveSummary(), isNull);

    final entry1 = await storage.saveSummary(samplePlan, rawJson: sampleMap);
    final active1 = await storage.getActiveSummary();
    expect(active1?.id, entry1.id);

    // Save second plan
    final entry2 = await storage.saveSummary(samplePlan, rawJson: sampleMap);
    final active2 = await storage.getActiveSummary();
    expect(active2?.id, entry2.id);

    // Switch back to first plan
    await storage.setActiveSummary(entry1.id);
    final activeSwitched = await storage.getActiveSummary();
    expect(activeSwitched?.id, entry1.id);
  });

  test('deleting active plan clears active id and removes item', () async {
    final entry = await storage.saveSummary(samplePlan, rawJson: sampleMap);
    expect(await storage.getActiveSummary(), isNotNull);

    await storage.deleteSummary(entry.id);
    expect(await storage.loadSummaries(), isEmpty);
    expect(await storage.getActiveSummary(), isNull);
  });
}

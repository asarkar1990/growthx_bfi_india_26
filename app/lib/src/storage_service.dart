import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class SavedSummary extends Equatable {
  const SavedSummary({
    required this.id,
    required this.patientName,
    required this.hospital,
    required this.createdAt,
    required this.medicationCount,
    required this.rawPlanJson,
    this.dischargeDate,
    this.isActive = false,
  });

  final String id;
  final String patientName;
  final String hospital;
  final String? dischargeDate;
  final DateTime createdAt;
  final int medicationCount;
  final Map<String, dynamic> rawPlanJson;
  final bool isActive;

  DischargePlan get plan => DischargePlan.fromJson(rawPlanJson);

  SavedSummary copyWith({
    String? id,
    String? patientName,
    String? hospital,
    String? dischargeDate,
    DateTime? createdAt,
    int? medicationCount,
    Map<String, dynamic>? rawPlanJson,
    bool? isActive,
  }) => SavedSummary(
    id: id ?? this.id,
    patientName: patientName ?? this.patientName,
    hospital: hospital ?? this.hospital,
    dischargeDate: dischargeDate ?? this.dischargeDate,
    createdAt: createdAt ?? this.createdAt,
    medicationCount: medicationCount ?? this.medicationCount,
    rawPlanJson: rawPlanJson ?? this.rawPlanJson,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientName': patientName,
    'hospital': hospital,
    'dischargeDate': dischargeDate,
    'createdAt': createdAt.toIso8601String(),
    'medicationCount': medicationCount,
    'rawPlanJson': rawPlanJson,
  };

  factory SavedSummary.fromJson(
    Map<String, dynamic> json, {
    bool isActive = false,
  }) {
    return SavedSummary(
      id: json['id'] as String,
      patientName: json['patientName'] as String,
      hospital: json['hospital'] as String,
      dischargeDate: json['dischargeDate'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      medicationCount: (json['medicationCount'] as num?)?.toInt() ?? 0,
      rawPlanJson: (json['rawPlanJson'] as Map).cast<String, dynamic>(),
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientName,
    hospital,
    dischargeDate,
    createdAt,
    medicationCount,
    rawPlanJson,
    isActive,
  ];
}

class CarePlanStorage {
  CarePlanStorage({SharedPreferences? preferences}) : _prefs = preferences;

  SharedPreferences? _prefs;

  static const _summariesKey = 'carepath_saved_summaries';
  static const _activeIdKey = 'carepath_active_summary_id';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<SavedSummary>> loadSummaries() async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_summariesKey) ?? [];
    final activeId = prefs.getString(_activeIdKey);

    final summaries = <SavedSummary>[];
    for (final item in rawList) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final id = decoded['id'] as String;
        summaries.add(SavedSummary.fromJson(decoded, isActive: id == activeId));
      } catch (_) {
        // Skip invalid/corrupt entries gracefully
      }
    }

    // Sort newest first
    summaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return summaries;
  }

  Future<SavedSummary?> getActiveSummary() async {
    final summaries = await loadSummaries();
    try {
      return summaries.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<SavedSummary> saveSummary(
    DischargePlan plan, {
    Map<String, dynamic>? rawJson,
    bool makeActive = true,
  }) async {
    final prefs = await _getPrefs();
    final id = 'plan_${DateTime.now().millisecondsSinceEpoch}';
    final jsonPayload = rawJson ?? _planToJson(plan);

    final entry = SavedSummary(
      id: id,
      patientName: plan.patientName,
      hospital: plan.hospital,
      dischargeDate: plan.dischargeDate,
      createdAt: DateTime.now(),
      medicationCount: plan.items
          .where((i) => !i.title.toLowerCase().contains('diet'))
          .length,
      rawPlanJson: jsonPayload,
      isActive: makeActive,
    );

    final summaries = await loadSummaries();
    // Insert new at front
    final updated = [
      entry,
      ...summaries.map(
        (s) => s.copyWith(isActive: makeActive ? false : s.isActive),
      ),
    ];

    final stringList = updated.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_summariesKey, stringList);
    if (makeActive) {
      await prefs.setString(_activeIdKey, id);
    }

    return entry;
  }

  Future<void> setActiveSummary(String id) async {
    final prefs = await _getPrefs();
    await prefs.setString(_activeIdKey, id);
  }

  Future<void> deleteSummary(String id) async {
    final prefs = await _getPrefs();
    final summaries = await loadSummaries();
    final remaining = summaries.where((s) => s.id != id).toList();

    final stringList = remaining.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_summariesKey, stringList);

    final currentActiveId = prefs.getString(_activeIdKey);
    if (currentActiveId == id) {
      await prefs.remove(_activeIdKey);
    }
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_summariesKey);
    await prefs.remove(_activeIdKey);
  }

  Map<String, dynamic> _planToJson(DischargePlan plan) {
    return {
      'schemaVersion': '1.0',
      'documentType': 'discharge_summary',
      'outputLanguage': plan.language,
      'patient': {
        'displayName': plan.patientName,
        'dischargeDate': plan.dischargeDate,
        'hospital': plan.hospital,
      },
      'overview': plan.overview,
      'medications': plan.items
          .where((i) => i.isMedication)
          .map(
            (i) => {
              'id': i.id,
              'name': i.title,
              'simplifiedInstruction': i.instruction,
              'timing': i.effectiveTimings
                  .map((timing) => timing.name)
                  .toList(),
              'applicableDays': i.days,
              'sourceEvidence': i.evidence,
              'status': i.status == ItemStatus.confirmedFromSource
                  ? 'confirmed_from_source'
                  : 'needs_confirmation',
              'confidence': 'high',
              'uncertaintyReason': i.uncertaintyReason,
            },
          )
          .toList(),
      'careInstructions': plan.items
          .where((i) => !i.isMedication)
          .map(
            (i) => {
              'id': i.id,
              'category': 'activity',
              'instruction': i.detail ?? i.instruction,
              'simplifiedInstruction': i.instruction,
              'timing': i.timing.name,
              'applicableDays': i.days,
              'sourceEvidence': i.evidence,
              'status': i.status == ItemStatus.confirmedFromSource
                  ? 'confirmed_from_source'
                  : 'needs_confirmation',
              'confidence': 'high',
              'uncertaintyReason': i.uncertaintyReason,
            },
          )
          .toList(),
      'followUps': plan.followUps
          .map(
            (f) => {
              'id': f.title,
              'type': f.type ?? 'appointment',
              'title': f.title,
              'relativeTiming': f.subtitle,
              'date': f.date,
              'locationOrDepartment': f.location,
              'preparation': f.preparation,
              'sourceEvidence': f.evidence,
              'status': 'confirmed_from_source',
              'confidence': 'high',
            },
          )
          .toList(),
      'warningSigns': plan.warnings
          .map(
            (w) => {
              'id': w.title,
              'sign': w.title,
              'action': w.subtitle,
              'sourceEvidence': w.evidence,
              'status': 'confirmed_from_source',
              'confidence': 'high',
            },
          )
          .toList(),
      'confirmationIssues': plan.issues
          .map(
            (issue) => {
              'id': issue.title,
              'title': issue.title,
              'questionForCareTeam': issue.question,
              'severity': issue.important ? 'important' : 'advisory',
            },
          )
          .toList(),
      'extractionWarnings': plan.extractionWarnings,
    };
  }
}

import 'package:equatable/equatable.dart';

enum ItemStatus { confirmedFromSource, needsConfirmation, conflict }

enum PlanTiming { morning, afternoon, evening, bedtime, anytime }

ItemStatus parseStatus(String value) => switch (value) {
  'confirmed_from_source' => ItemStatus.confirmedFromSource,
  'needs_confirmation' => ItemStatus.needsConfirmation,
  'conflict' => ItemStatus.conflict,
  _ => throw FormatException('Unknown safety status: $value'),
};

PlanTiming parseTiming(String value) => switch (value) {
  'morning' => PlanTiming.morning,
  'afternoon' => PlanTiming.afternoon,
  'evening' => PlanTiming.evening,
  'bedtime' => PlanTiming.bedtime,
  'anytime' => PlanTiming.anytime,
  _ => throw FormatException('Unknown timing: $value'),
};

class PlanItem extends Equatable {
  const PlanItem({
    required this.id,
    required this.title,
    required this.instruction,
    required this.timing,
    required this.days,
    required this.evidence,
    required this.status,
    this.detail,
    this.uncertaintyReason,
  });
  final String id, title, instruction, evidence;
  final String? detail, uncertaintyReason;
  final PlanTiming timing;
  final List<int> days;
  final ItemStatus status;
  bool get reminderEligible =>
      status == ItemStatus.confirmedFromSource &&
      timing != PlanTiming.anytime &&
      days.isNotEmpty;

  factory PlanItem.fromJson(
    Map<String, dynamic> json, {
    required bool medication,
  }) {
    final evidence = json['sourceEvidence'];
    if (evidence is! String || evidence.trim().isEmpty) {
      throw const FormatException('Every plan item requires source evidence');
    }
    final days = (json['applicableDays'] as List).cast<int>();
    if (days.any((day) => day < 1 || day > 7)) {
      throw const FormatException('Plan day must be 1–7');
    }
    final rawTiming = medication
        ? (json['timing'] as List).first as String
        : json['timing'] as String;
    return PlanItem(
      id: json['id'] as String,
      title: medication
          ? json['name'] as String
          : _categoryLabel(json['category'] as String),
      instruction: json['simplifiedInstruction'] as String,
      timing: parseTiming(rawTiming),
      days: days,
      evidence: evidence,
      status: parseStatus(json['status'] as String),
      uncertaintyReason: json['uncertaintyReason'] as String?,
      detail: medication
          ? [
              json['dose'],
              json['frequency'],
              json['duration'],
            ].whereType<String>().join(' • ')
          : json['instruction'] as String?,
    );
  }

  static String _categoryLabel(String value) => switch (value) {
    'activity' => 'Activity',
    'diet' => 'Diet',
    'wound_care' => 'Wound care',
    _ => 'Care instruction',
  };
  @override
  List<Object?> get props => [
    id,
    title,
    instruction,
    timing,
    days,
    evidence,
    status,
    detail,
    uncertaintyReason,
  ];
}

class ConfirmationIssue extends Equatable {
  const ConfirmationIssue({
    required this.title,
    required this.question,
    required this.important,
  });
  final String title, question;
  final bool important;
  @override
  List<Object?> get props => [title, question, important];
}

class EvidenceNote extends Equatable {
  const EvidenceNote({
    required this.title,
    required this.subtitle,
    required this.evidence,
    required this.status,
  });
  final String title, subtitle, evidence;
  final ItemStatus status;
  @override
  List<Object?> get props => [title, subtitle, evidence, status];
}

class DischargePlan extends Equatable {
  const DischargePlan({
    required this.language,
    required this.patientName,
    required this.hospital,
    required this.overview,
    required this.items,
    required this.issues,
    required this.followUps,
    required this.warnings,
    required this.extractionWarnings,
  });
  final String language, patientName, hospital, overview;
  final List<PlanItem> items;
  final List<ConfirmationIssue> issues;
  final List<EvidenceNote> followUps, warnings;
  final List<String> extractionWarnings;

  factory DischargePlan.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != '1.0' ||
        !['en', 'bn', 'hi'].contains(json['outputLanguage'])) {
      throw const FormatException('Unsupported plan schema');
    }
    final patient = json['patient'] as Map<String, dynamic>;
    EvidenceNote note(
      Map<String, dynamic> value,
      String title,
      String subtitle,
    ) {
      final evidence = value['sourceEvidence'];
      if (evidence is! String || evidence.isEmpty) {
        throw const FormatException('Evidence is required');
      }
      return EvidenceNote(
        title: title,
        subtitle: subtitle,
        evidence: evidence,
        status: parseStatus(value['status'] as String),
      );
    }

    return DischargePlan(
      language: json['outputLanguage'] as String,
      patientName: patient['displayName'] as String? ?? 'Your',
      hospital: patient['hospital'] as String? ?? 'Hospital',
      overview: json['overview'] as String,
      items: [
        ...(json['medications'] as List).map(
          (e) => PlanItem.fromJson(
            (e as Map).cast<String, dynamic>(),
            medication: true,
          ),
        ),
        ...(json['careInstructions'] as List).map(
          (e) => PlanItem.fromJson(
            (e as Map).cast<String, dynamic>(),
            medication: false,
          ),
        ),
      ],
      issues: (json['confirmationIssues'] as List).map((e) {
        final value = (e as Map).cast<String, dynamic>();
        return ConfirmationIssue(
          title: value['title'] as String,
          question: value['questionForCareTeam'] as String,
          important: value['severity'] == 'important',
        );
      }).toList(),
      followUps: (json['followUps'] as List).map((e) {
        final v = (e as Map).cast<String, dynamic>();
        return note(
          v,
          v['title'] as String,
          v['relativeTiming'] as String? ??
              v['date'] as String? ??
              'Schedule unclear',
        );
      }).toList(),
      warnings: (json['warningSigns'] as List).map((e) {
        final v = (e as Map).cast<String, dynamic>();
        return note(
          v,
          v['sign'] as String,
          v['action'] as String? ?? 'Contact your care team',
        );
      }).toList(),
      extractionWarnings: (json['extractionWarnings'] as List).cast<String>(),
    );
  }
  @override
  List<Object?> get props => [
    language,
    patientName,
    hospital,
    overview,
    items,
    issues,
    followUps,
    warnings,
    extractionWarnings,
  ];
}

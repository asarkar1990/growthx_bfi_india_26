import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'models.dart';

enum CarePlanPhase { upload, processing, ready, reminders, failure }

class CarePlanState extends Equatable {
  const CarePlanState({
    this.phase = CarePlanPhase.upload,
    this.language = 'en',
    this.fileName,
    this.usingSample = false,
    this.processingStage = 0,
    this.selectedDay = 1,
    this.plan,
    this.error,
  });
  final CarePlanPhase phase;
  final String language;
  final String? fileName, error;
  final bool usingSample;
  final int processingStage, selectedDay;
  final DischargePlan? plan;
  CarePlanState copyWith({
    CarePlanPhase? phase,
    String? language,
    String? fileName,
    bool? usingSample,
    int? processingStage,
    int? selectedDay,
    DischargePlan? plan,
    String? error,
    bool clearError = false,
  }) => CarePlanState(
    phase: phase ?? this.phase,
    language: language ?? this.language,
    fileName: fileName ?? this.fileName,
    usingSample: usingSample ?? this.usingSample,
    processingStage: processingStage ?? this.processingStage,
    selectedDay: selectedDay ?? this.selectedDay,
    plan: plan ?? this.plan,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => [
    phase,
    language,
    fileName,
    usingSample,
    processingStage,
    selectedDay,
    plan,
    error,
  ];
}

class CarePlanCubit extends Cubit<CarePlanState> {
  CarePlanCubit({Future<String> Function(String)? fixtureLoader})
    : _fixtureLoader =
          fixtureLoader ??
          ((lang) =>
              rootBundle.loadString('assets/samples/sample_plan_$lang.json')),
      super(const CarePlanState());
  final Future<String> Function(String) _fixtureLoader;
  void setLanguage(String language) => emit(state.copyWith(language: language));
  void selectFile(String name) => emit(
    state.copyWith(fileName: name, usingSample: false, clearError: true),
  );
  void useSample() => emit(
    state.copyWith(
      fileName: 'Synthetic discharge summary.pdf',
      usingSample: true,
      clearError: true,
    ),
  );
  void selectDay(int day) => emit(state.copyWith(selectedDay: day));
  void showReminders() => emit(state.copyWith(phase: CarePlanPhase.reminders));
  void showPlan() => emit(state.copyWith(phase: CarePlanPhase.ready));
  void reset() => emit(CarePlanState(language: state.language));

  Future<void> createPlan({
    Duration stageDelay = const Duration(milliseconds: 520),
  }) async {
    if (state.fileName == null) {
      emit(state.copyWith(error: 'Choose a document or use the sample first.'));
      return;
    }
    emit(
      state.copyWith(
        phase: CarePlanPhase.processing,
        processingStage: 0,
        clearError: true,
      ),
    );
    try {
      for (var stage = 1; stage < 3; stage++) {
        await Future<void>.delayed(stageDelay);
        emit(state.copyWith(processingStage: stage));
      }
      // The bundled fixture guarantees the live demo while real uploads use the same strict contract once the provider is configured.
      final json =
          jsonDecode(await _fixtureLoader(state.language))
              as Map<String, dynamic>;
      emit(
        state.copyWith(
          phase: CarePlanPhase.ready,
          plan: DischargePlan.fromJson(json),
          selectedDay: 1,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          phase: CarePlanPhase.failure,
          error:
              'We could not safely create this plan. Retry or use the sample document.',
        ),
      );
    }
  }
}

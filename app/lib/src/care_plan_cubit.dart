import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_api.dart';
import 'models.dart';

enum CarePlanPhase { upload, processing, ready, reminders, failure }

class CarePlanState extends Equatable {
  const CarePlanState({
    this.phase = CarePlanPhase.upload,
    this.language = 'en',
    this.fileName,
    this.fileBytes,
    this.usingSample = false,
    this.processingStage = 0,
    this.selectedDay = 1,
    this.plan,
    this.error,
    this.apiBaseUrl = CarePlanApi.envBaseUrl,
    this.backendConnected,
  });

  final CarePlanPhase phase;
  final String language;
  final String? fileName, error;
  final Uint8List? fileBytes;
  final bool usingSample;
  final int processingStage, selectedDay;
  final DischargePlan? plan;
  final String apiBaseUrl;
  final bool? backendConnected;

  CarePlanState copyWith({
    CarePlanPhase? phase,
    String? language,
    String? fileName,
    Uint8List? fileBytes,
    bool? usingSample,
    int? processingStage,
    int? selectedDay,
    DischargePlan? plan,
    String? error,
    String? apiBaseUrl,
    bool? backendConnected,
    bool clearError = false,
    bool clearFileBytes = false,
  }) => CarePlanState(
    phase: phase ?? this.phase,
    language: language ?? this.language,
    fileName: fileName ?? this.fileName,
    fileBytes: clearFileBytes ? null : fileBytes ?? this.fileBytes,
    usingSample: usingSample ?? this.usingSample,
    processingStage: processingStage ?? this.processingStage,
    selectedDay: selectedDay ?? this.selectedDay,
    plan: plan ?? this.plan,
    error: clearError ? null : error ?? this.error,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    backendConnected: backendConnected ?? this.backendConnected,
  );

  @override
  List<Object?> get props => [
    phase,
    language,
    fileName,
    fileBytes,
    usingSample,
    processingStage,
    selectedDay,
    plan,
    error,
    apiBaseUrl,
    backendConnected,
  ];
}

class CarePlanCubit extends Cubit<CarePlanState> {
  CarePlanCubit({
    CarePlanApi? api,
    Future<String> Function(String)? fixtureLoader,
  }) : _api = api ?? CarePlanApi(),
       _fixtureLoader =
           fixtureLoader ??
           ((lang) =>
               rootBundle.loadString('assets/samples/sample_plan_$lang.json')),
       super(CarePlanState(apiBaseUrl: (api ?? CarePlanApi()).baseUrl));

  CarePlanApi _api;
  final Future<String> Function(String) _fixtureLoader;

  void setLanguage(String language) => emit(state.copyWith(language: language));

  void selectFile(String name, {Uint8List? bytes}) => emit(
    state.copyWith(
      fileName: name,
      fileBytes: bytes,
      usingSample: false,
      clearError: true,
    ),
  );

  void useSample() => emit(
    state.copyWith(
      fileName: 'Synthetic discharge summary.pdf',
      usingSample: true,
      clearError: true,
      clearFileBytes: true,
    ),
  );

  void setApiBaseUrl(String url) {
    final normalized = CarePlanApi.normalizeBaseUrl(url);
    _api = CarePlanApi(baseUrl: normalized);
    emit(
      state.copyWith(
        apiBaseUrl: normalized,
        backendConnected: null,
        clearError: true,
      ),
    );
    checkBackendHealth();
  }

  Future<void> checkBackendHealth() async {
    final healthy = await _api.checkHealth();
    emit(state.copyWith(backendConnected: healthy));
  }

  void selectDay(int day) => emit(state.copyWith(selectedDay: day));
  void showReminders() => emit(state.copyWith(phase: CarePlanPhase.reminders));
  void showPlan() => emit(state.copyWith(phase: CarePlanPhase.ready));
  void reset() => emit(
    CarePlanState(
      language: state.language,
      apiBaseUrl: state.apiBaseUrl,
      backendConnected: state.backendConnected,
    ),
  );

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

      DischargePlan plan;
      if (state.usingSample) {
        final json =
            jsonDecode(await _fixtureLoader(state.language))
                as Map<String, dynamic>;
        plan = DischargePlan.fromJson(json);
      } else {
        // Real document upload: call the backend API endpoint
        if (state.fileBytes == null) {
          throw const ApiException(
            code: 'FILE_READ_ERROR',
            message:
                'Unable to read file content. Please re-select the document.',
            statusCode: 400,
          );
        }

        plan = await _api.createPlan(
          language: state.language,
          useSample: false,
          fileName: state.fileName,
          fileBytes: state.fileBytes,
        );
      }

      emit(
        state.copyWith(phase: CarePlanPhase.ready, plan: plan, selectedDay: 1),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(phase: CarePlanPhase.failure, error: e.message));
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

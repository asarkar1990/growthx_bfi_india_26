import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_api.dart';
import 'models.dart';
import 'storage_service.dart';

enum CarePlanPhase { upload, processing, confirming, ready, reminders, failure }

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
    this.pendingPlan,
    this.error,
    this.apiBaseUrl = CarePlanApi.envBaseUrl,
    this.backendConnected,
    this.savedSummaries = const [],
    this.activeSummaryId,
    this.currentTab = 0,
  });

  final CarePlanPhase phase;
  final String language;
  final String? fileName, error;
  final Uint8List? fileBytes;
  final bool usingSample;
  final int processingStage, selectedDay;
  final DischargePlan? plan;
  final DischargePlan? pendingPlan;
  final String apiBaseUrl;
  final bool? backendConnected;
  final List<SavedSummary> savedSummaries;
  final String? activeSummaryId;
  final int currentTab;

  CarePlanState copyWith({
    CarePlanPhase? phase,
    String? language,
    String? fileName,
    Uint8List? fileBytes,
    bool? usingSample,
    int? processingStage,
    int? selectedDay,
    DischargePlan? plan,
    DischargePlan? pendingPlan,
    String? error,
    String? apiBaseUrl,
    bool? backendConnected,
    List<SavedSummary>? savedSummaries,
    String? activeSummaryId,
    int? currentTab,
    bool clearError = false,
    bool clearFileBytes = false,
    bool clearPendingPlan = false,
    bool clearPlan = false,
  }) => CarePlanState(
    phase: phase ?? this.phase,
    language: language ?? this.language,
    fileName: fileName ?? this.fileName,
    fileBytes: clearFileBytes ? null : fileBytes ?? this.fileBytes,
    usingSample: usingSample ?? this.usingSample,
    processingStage: processingStage ?? this.processingStage,
    selectedDay: selectedDay ?? this.selectedDay,
    plan: clearPlan ? null : plan ?? this.plan,
    pendingPlan: clearPendingPlan ? null : pendingPlan ?? this.pendingPlan,
    error: clearError ? null : error ?? this.error,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    backendConnected: backendConnected ?? this.backendConnected,
    savedSummaries: savedSummaries ?? this.savedSummaries,
    activeSummaryId: activeSummaryId ?? this.activeSummaryId,
    currentTab: currentTab ?? this.currentTab,
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
    pendingPlan,
    error,
    apiBaseUrl,
    backendConnected,
    savedSummaries,
    activeSummaryId,
    currentTab,
  ];
}

class CarePlanCubit extends Cubit<CarePlanState> {
  CarePlanCubit({CarePlanApi? api, CarePlanStorage? storage})
    : _api = api ?? CarePlanApi(),
      _storage = storage ?? CarePlanStorage(),
      super(CarePlanState(apiBaseUrl: (api ?? CarePlanApi()).baseUrl)) {
    initStorage();
  }

  CarePlanApi _api;
  final CarePlanStorage _storage;

  Future<void> initStorage() async {
    final summaries = await _storage.loadSummaries();
    SavedSummary? active;
    try {
      active = summaries.firstWhere((s) => s.isActive);
    } catch (_) {
      active = null;
    }

    if (active != null) {
      emit(
        state.copyWith(
          savedSummaries: summaries,
          activeSummaryId: active.id,
          plan: active.plan,
          phase: CarePlanPhase.ready,
        ),
      );
    } else {
      emit(state.copyWith(savedSummaries: summaries));
    }
  }

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

  void switchTab(int tab) => emit(state.copyWith(currentTab: tab));
  void selectDay(int day) => emit(state.copyWith(selectedDay: day));
  void showReminders() => emit(state.copyWith(phase: CarePlanPhase.reminders));
  void showPlan() => emit(state.copyWith(phase: CarePlanPhase.ready));
  void startNewUpload() => emit(
    state.copyWith(
      phase: CarePlanPhase.upload,
      currentTab: 0,
      clearFileBytes: true,
      clearError: true,
    ),
  );

  void reset() => emit(
    CarePlanState(
      language: state.language,
      apiBaseUrl: state.apiBaseUrl,
      backendConnected: state.backendConnected,
      savedSummaries: state.savedSummaries,
      activeSummaryId: state.activeSummaryId,
      plan: state.plan,
      phase: state.plan != null ? CarePlanPhase.ready : CarePlanPhase.upload,
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

      if (!state.usingSample && state.fileBytes == null) {
        throw const ApiException(
          code: 'FILE_READ_ERROR',
          message:
              'Unable to read file content. Please re-select the document.',
          statusCode: 400,
        );
      }

      final plan = await _api.createPlan(
        language: state.language,
        useSample: state.usingSample,
        fileName: state.fileName,
        fileBytes: state.fileBytes,
      );

      // Transition to confirmation view
      emit(
        state.copyWith(
          phase: CarePlanPhase.confirming,
          pendingPlan: plan,
          selectedDay: 1,
        ),
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

  Future<void> confirmAndSavePendingPlan() async {
    final pending = state.pendingPlan;
    if (pending == null) return;

    final entry = await _storage.saveSummary(pending, makeActive: true);
    final summaries = await _storage.loadSummaries();

    emit(
      state.copyWith(
        phase: CarePlanPhase.ready,
        plan: pending,
        clearPendingPlan: true,
        savedSummaries: summaries,
        activeSummaryId: entry.id,
        currentTab: 0,
      ),
    );
  }

  void discardPendingPlan() {
    emit(
      state.copyWith(
        phase: state.plan != null ? CarePlanPhase.ready : CarePlanPhase.upload,
        clearPendingPlan: true,
        clearError: true,
      ),
    );
  }

  Future<void> setActiveSummary(String id) async {
    await _storage.setActiveSummary(id);
    final summaries = await _storage.loadSummaries();
    SavedSummary? active;
    try {
      active = summaries.firstWhere((s) => s.id == id);
    } catch (_) {
      active = null;
    }

    if (active != null) {
      emit(
        state.copyWith(
          savedSummaries: summaries,
          activeSummaryId: id,
          plan: active.plan,
          phase: CarePlanPhase.ready,
          currentTab: 0,
        ),
      );
    }
  }

  Future<void> deleteSummary(String id) async {
    final wasActive = state.activeSummaryId == id;
    await _storage.deleteSummary(id);
    final summaries = await _storage.loadSummaries();

    if (wasActive) {
      emit(
        state.copyWith(
          savedSummaries: summaries,
          activeSummaryId: null,
          clearPlan: true,
          phase: CarePlanPhase.upload,
        ),
      );
    } else {
      emit(state.copyWith(savedSummaries: summaries));
    }
  }
}

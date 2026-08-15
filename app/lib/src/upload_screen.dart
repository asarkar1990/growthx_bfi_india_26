import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_cubit.dart';
import 'history_screen.dart';
import 'models.dart';
import 'plan_screen.dart';
import 'theme.dart';
import 'voice_chat_cubit.dart';
import 'voice_chat_screen.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarePlanCubit>().state;
    final cubit = context.read<CarePlanCubit>();

    final Widget body;
    if (state.currentTab == 1) {
      body = const HistoryScreen();
    } else {
      body = switch (state.phase) {
        CarePlanPhase.processing => const ProcessingView(),
        CarePlanPhase.confirming => ConfirmationView(
          plan: state.pendingPlan ?? state.plan!,
        ),
        CarePlanPhase.ready || CarePlanPhase.reminders => const PlanScreen(),
        CarePlanPhase.failure => FailureView(
          message: state.error ?? 'Something went wrong.',
        ),
        _ => const UploadView(),
      };
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        height: 74,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: Color(0xFF281E40), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home / Active Plan Tab
            Expanded(
              child: InkWell(
                onTap: () => cubit.switchTab(0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.currentTab == 0
                          ? Icons.home_rounded
                          : Icons.home_outlined,
                      color: state.currentTab == 0
                          ? AppTheme.lavender
                          : const Color(0xFF9C93AC),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.plan != null ? 'Active Plan' : 'Home',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: state.currentTab == 0
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: state.currentTab == 0
                            ? Colors.white
                            : const Color(0xFF9C93AC),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center Elevated Glowing Mic Button
            GestureDetector(
              onTap: () {
                final activePlan = state.plan ?? state.pendingPlan;
                if (activePlan != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider(
                        create: (_) => VoiceChatCubit(),
                        child: VoiceChatScreen(plan: activePlan),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please upload or activate a discharge plan first to chat.',
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            // Summaries Tab
            Expanded(
              child: InkWell(
                onTap: () => cubit.switchTab(1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Badge(
                      isLabelVisible: state.savedSummaries.isNotEmpty,
                      label: Text('${state.savedSummaries.length}'),
                      backgroundColor: AppTheme.lavender,
                      child: Icon(
                        state.currentTab == 1
                            ? Icons.folder_shared_rounded
                            : Icons.folder_shared_outlined,
                        color: state.currentTab == 1
                            ? AppTheme.lavender
                            : const Color(0xFF9C93AC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Summaries',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: state.currentTab == 1
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: state.currentTab == 1
                            ? Colors.white
                            : const Color(0xFF9C93AC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({required this.child, this.appBar, super.key});
  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child,
        ),
      ),
    ),
  );
}

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  void _showServerSettings(BuildContext context) {
    final cubit = context.read<CarePlanCubit>();
    final controller = TextEditingController(text: cubit.state.apiBaseUrl);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B162B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<CarePlanCubit, CarePlanState>(
          builder: (ctx, state) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B4B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.dns_rounded,
                          color: AppTheme.lavender,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Backend API Configuration',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Set the FastAPI root URL (e.g. your laptop’s local server).',
                    style: TextStyle(fontSize: 13, color: Color(0xFFB9B1C8)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'API Root URL',
                      hintText: 'http://127.0.0.1:8000',
                      prefixIcon: const Icon(Icons.link_rounded),
                      filled: true,
                      fillColor: const Color(0xFF13101E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF33294E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.lavender),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('127.0.0.1:8000 (Laptop)'),
                        onPressed: () {
                          controller.text = 'http://127.0.0.1:8000';
                          cubit.setApiBaseUrl('http://127.0.0.1:8000');
                        },
                      ),
                      ActionChip(
                        label: const Text('10.0.2.2:8000 (Android)'),
                        onPressed: () {
                          controller.text = 'http://10.0.2.2:8000';
                          cubit.setApiBaseUrl('http://10.0.2.2:8000');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (state.backendConnected != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: state.backendConnected!
                            ? const Color(0xFF10281E)
                            : const Color(0xFF2C1418),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.backendConnected!
                              ? const Color(0xFF225B40)
                              : const Color(0xFF6B262F),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            state.backendConnected!
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 18,
                            color: state.backendConnected!
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.backendConnected!
                                  ? 'Connected! Backend is healthy at ${state.apiBaseUrl}'
                                  : 'Could not reach backend at ${state.apiBaseUrl}',
                              style: TextStyle(
                                fontSize: 12,
                                color: state.backendConnected!
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          cubit.setApiBaseUrl(controller.text);
                          cubit.checkBackendHealth();
                        },
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Test Connection'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          cubit.setApiBaseUrl(controller.text);
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Save & Close'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarePlanCubit>().state;
    final statusColor = state.backendConnected == true
        ? Colors.greenAccent
        : state.backendConnected == false
        ? Colors.redAccent
        : AppTheme.lavender;

    return AppBar(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_rounded, color: AppTheme.lavender, size: 24),
          SizedBox(width: 10),
          Text(
            'CarePath',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'API settings',
          onPressed: () => _showServerSettings(context),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.settings_outlined),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.route_rounded, color: AppTheme.lavender, size: 24),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          'CarePath',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class UploadView extends StatelessWidget {
  const UploadView({super.key});

  Future<void> _pick(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result != null && context.mounted) {
      final file = result.files.single;
      context.read<CarePlanCubit>().selectFile(file.name, bytes: file.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CarePlanCubit>();
    final state = context.watch<CarePlanCubit>().state;
    return PageShell(
      appBar: const HomeAppBar(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Get Well Soon',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start with your discharge summary.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB9B1C8), height: 1.45),
            ),
            const SizedBox(height: 26),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _pick(context),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B4B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: AppTheme.lavender,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        state.fileName ?? 'Add discharge summary',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.fileName == null
                            ? 'PDF, PNG or JPG'
                            : 'Ready to turn into a plan',
                        style: const TextStyle(color: Color(0xFF9C93AC)),
                      ),
                      const SizedBox(height: 14),
                      if (state.fileName == null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _pick(context),
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Upload discharge summary'),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _pick(context),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Replace document'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: const TextStyle(color: AppTheme.amber)),
            ],
            if (state.fileName != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF302746)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.language,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                      DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
                    ],
                    onChanged: (language) {
                      if (language != null) cubit.setLanguage(language);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => cubit.createPlan(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Create recovery plan'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'CarePath organises your instructions — it does not replace your care team.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF9C93AC)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmationView extends StatelessWidget {
  const ConfirmationView({required this.plan, super.key});
  final DischargePlan plan;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CarePlanCubit>();
    final medCount = plan.items.length;

    return PageShell(
      appBar: const HomeAppBar(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1B4B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF45316E)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF382364),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: AppTheme.lavender,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm & Save Plan',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Review full extracted details before activating.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB9B1C8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. Patient & Hospital Header Card
            Card(
              elevation: 0,
              color: const Color(0xFF1B162C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF33294E)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.patientName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                plan.hospital,
                                style: const TextStyle(
                                  color: Color(0xFFB4ACCE),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (plan.dischargeDate != null &&
                            plan.dischargeDate!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B1F48),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'DISCHARGED',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.lavender,
                                    letterSpacing: .5,
                                  ),
                                ),
                                Text(
                                  plan.dischargeDate!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFF2D2346)),
                    const SizedBox(height: 14),
                    const Text(
                      'CLINICAL SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        color: Color(0xFF9E95B2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.overview,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFFD6D0E4),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Full Medications Section
            Row(
              children: [
                const Icon(
                  Icons.medication_outlined,
                  size: 18,
                  color: AppTheme.lavender,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MEDICATIONS TO CONFIRM ($medCount)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                      color: AppTheme.lavender,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...plan.items.map((item) {
              final uncertain = item.status != ItemStatus.confirmedFromSource;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161224),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: uncertain
                          ? const Color(0xFF5A4418)
                          : const Color(0xFF2C2248),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF241A3E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _timingPill(item.timing),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lavender,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.instruction,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFFE2DCED),
                          height: 1.4,
                        ),
                      ),
                      if (item.detail != null && item.detail!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.detail!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB4ACCE),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0916),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SOURCE EVIDENCE:',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .8,
                                color: Color(0xFF8E86A2),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '“${item.evidence}”',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFCEC7D8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),

            // 3. Follow-Ups & Tests (if any)
            if (plan.followUps.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: AppTheme.lavender,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FOLLOW-UPS & TESTS (${plan.followUps.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                        color: AppTheme.lavender,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...plan.followUps.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161224),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2C2248)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (f.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            f.subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFB4ACCE),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '“${f.evidence}”',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF9C93AC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 4. Warning Signs (if any)
            if (plan.warnings.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Colors.amberAccent,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WARNING SIGNS & EMERGENCY ADVICE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...plan.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24151B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF5A2633)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFB4B4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Action: ${w.subtitle}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFFFD6D6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '“${w.evidence}”',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFD69A9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 5. Actions Footer
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                cubit.confirmAndSavePendingPlan();
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                'Confirm & Activate Recovery Plan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF45366E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                cubit.discardPendingPlan();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Discard / Re-upload'),
            ),
          ],
        ),
      ),
    );
  }

  static String _timingPill(PlanTiming timing) {
    return switch (timing) {
      PlanTiming.morning => 'Morning (8:00 AM)',
      PlanTiming.afternoon => 'Afternoon (1:00 PM)',
      PlanTiming.evening => 'Evening (6:00 PM)',
      PlanTiming.bedtime => 'Bedtime (9:00 PM)',
      PlanTiming.anytime => 'As Needed (SOS)',
    };
  }
}

class ProcessingView extends StatelessWidget {
  const ProcessingView({super.key});
  @override
  Widget build(BuildContext context) {
    final stage = context.watch<CarePlanCubit>().state.processingStage;
    const labels = [
      'Reading the document',
      'Organising instructions',
      'Creating your day-by-day plan',
    ];
    return PageShell(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1B4B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Making the next 7 days clearer',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'No invented percentages — we’ll show each honest processing stage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9C93AC)),
            ),
            const SizedBox(height: 34),
            ...List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(
                      i < stage
                          ? Icons.check_circle_rounded
                          : i == stage
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: i <= stage
                          ? AppTheme.lavender
                          : const Color(0xFF625A70),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: i == stage
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: i <= stage
                              ? Colors.white
                              : const Color(0xFF81798E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => PageShell(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            size: 58,
            color: AppTheme.amber,
          ),
          const SizedBox(height: 20),
          Text(
            'We couldn’t safely read that',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: context.read<CarePlanCubit>().reset,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

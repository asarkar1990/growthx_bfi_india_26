import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_cubit.dart';
import 'plan_screen.dart';
import 'theme.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CarePlanCubit, CarePlanState>(
        builder: (context, state) => switch (state.phase) {
          CarePlanPhase.processing => const ProcessingView(),
          CarePlanPhase.ready || CarePlanPhase.reminders => const PlanScreen(),
          CarePlanPhase.failure => FailureView(
            message: state.error ?? 'Something went wrong.',
          ),
          _ => const UploadView(),
        },
      );
}

class PageShell extends StatelessWidget {
  const PageShell({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
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

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.violet,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.route_rounded, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text(
          'CarePath',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'INDIA • DEMO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.lavender,
          ),
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
      withData: false,
    );
    if (result != null && context.mounted) {
      context.read<CarePlanCubit>().selectFile(result.files.single.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CarePlanCubit>();
    final state = context.watch<CarePlanCubit>().state;
    return PageShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(),
            const SizedBox(height: 42),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1B4B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'YOUR FIRST 7 DAYS, MADE CLEAR',
                style: TextStyle(
                  color: AppTheme.lavender,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recovery instructions,\nwithout the overwhelm.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 14),
            Text(
              'Upload your discharge summary. We’ll organise exactly what the hospital wrote into a simple day-by-day plan.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFB9B1C8)),
            ),
            const SizedBox(height: 28),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _pick(context),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B4B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: AppTheme.lavender,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        state.fileName ?? 'Choose discharge document',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.fileName == null
                            ? 'PDF, PNG or JPG • up to 10 MB'
                            : 'Ready to organise • tap to replace',
                        style: const TextStyle(color: Color(0xFF9C93AC)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _pick(context),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Browse files'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Plan language',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final option in const [
                  ('en', 'English'),
                  ('bn', 'বাংলা'),
                  ('hi', 'हिन्दी'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(option.$2, textAlign: TextAlign.center),
                        ),
                        selected: state.language == option.$1,
                        onSelected: (_) => cubit.setLanguage(option.$1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: cubit.useSample,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Use synthetic demo document'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: const TextStyle(color: AppTheme.amber)),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => cubit.createPlan(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Create my recovery plan'),
            ),
            const SizedBox(height: 20),
            const _SafetyNote(),
          ],
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF151221),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF302746)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppTheme.lavender, size: 21),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'CarePath organises instructions from your discharge document. It does not provide medical advice or replace your doctor. Confirm unclear or conflicting information with your care team.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFB9B1C8),
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
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
                    Text(
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

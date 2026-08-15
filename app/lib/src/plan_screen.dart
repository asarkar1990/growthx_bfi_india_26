import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_cubit.dart';
import 'models.dart';
import 'theme.dart';
import 'upload_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarePlanCubit>().state;
    if (state.phase == CarePlanPhase.reminders) {
      return const ReminderSetupView();
    }
    final plan = state.plan!;
    return PageShell(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: context.read<CarePlanCubit>().reset,
                        tooltip: 'Start over',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(child: Brand()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${plan.patientName}’s recovery plan',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${plan.hospital} • 7-day plan',
                    style: const TextStyle(color: Color(0xFF9C93AC)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A1B4B), Color(0xFF181329)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.lavender,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            plan.overview,
                            style: const TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ConfirmationPanel(issues: plan.issues),
                  const SizedBox(height: 26),
                  Text(
                    'Your week',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayHeader(
              selected: state.selectedDay,
              onSelected: context.read<CarePlanCubit>().selectDay,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            sliver: SliverList.list(
              children: [
                _DayTimeline(plan: plan, day: state.selectedDay),
                const SizedBox(height: 28),
                _EvidenceSection(
                  title: 'Follow-ups & tests',
                  icon: Icons.calendar_month_outlined,
                  notes: plan.followUps,
                ),
                const SizedBox(height: 18),
                _EvidenceSection(
                  title: 'Warning signs from your document',
                  icon: Icons.warning_amber_rounded,
                  notes: plan.warnings,
                  urgent: true,
                ),
                if (plan.extractionWarnings.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.amber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              plan.extractionWarnings.join('\n'),
                              style: const TextStyle(color: Color(0xFFD7C9A1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: context.read<CarePlanCubit>().showReminders,
                  icon: const Icon(Icons.notifications_none_rounded),
                  label: const Text('Review private reminders'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'CarePath organises source instructions; it does not provide medical advice. Confirm unclear information with your care team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF81798E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationPanel extends StatelessWidget {
  const _ConfirmationPanel({required this.issues});
  final List<ConfirmationIssue> issues;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF2B2213),
      border: Border.all(color: const Color(0xFF655020)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppTheme.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${issues.length} items to confirm',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFFE6A5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Ask your care team before acting on these unclear instructions.',
          style: TextStyle(color: Color(0xFFD7C9A1)),
        ),
        const SizedBox(height: 12),
        ...issues.map(
          (e) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              leading: Icon(
                e.important ? Icons.priority_high : Icons.edit_note,
                color: AppTheme.amber,
              ),
              title: Text(
                e.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(e.important ? 'Important' : 'Advisory'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ask: ${e.question}',
                    style: const TextStyle(color: Color(0xFFE8D9B2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DayHeader extends SliverPersistentHeaderDelegate {
  _DayHeader({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: AppTheme.ink,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) {
        final day = index + 1;
        return ChoiceChip(
          label: Text('Day $day'),
          selected: day == selected,
          onSelected: (_) => onSelected(day),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: day == selected ? Colors.white : const Color(0xFFB9B1C8),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemCount: 7,
    ),
  );
  @override
  bool shouldRebuild(covariant _DayHeader old) => old.selected != selected;
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.plan, required this.day});
  final DischargePlan plan;
  final int day;
  @override
  Widget build(BuildContext context) {
    final items = plan.items.where((e) => e.days.contains(day)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Day $day timeline',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap any item to see exactly where it came from.',
          style: TextStyle(color: Color(0xFF9C93AC)),
        ),
        const SizedBox(height: 16),
        ...PlanTiming.values.map((timing) {
          final timed = items.where((e) => e.timing == timing).toList();
          if (timed.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _timingIcon(timing),
                      size: 18,
                      color: AppTheme.lavender,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timingName(timing).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lavender,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ...timed.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlanItemCard(item: item),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({required this.item});
  final PlanItem item;
  @override
  Widget build(BuildContext context) {
    final uncertain = item.status != ItemStatus.confirmedFromSource;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: uncertain
                ? const Color(0xFF3A2C14)
                : const Color(0xFF282040),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            uncertain ? Icons.help_outline : Icons.check_rounded,
            color: uncertain ? AppTheme.amber : AppTheme.lavender,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.instruction),
              if (item.detail?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    item.detail!,
                    style: const TextStyle(
                      color: Color(0xFF9C93AC),
                      fontSize: 13,
                    ),
                  ),
                ),
              if (uncertain)
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Text(
                    'NEEDS CONFIRMATION',
                    style: TextStyle(
                      color: AppTheme.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF100D19),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FROM YOUR DOCUMENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppTheme.lavender,
                  ),
                ),
                const SizedBox(height: 7),
                SelectableText(
                  '“${item.evidence}”',
                  style: const TextStyle(
                    color: Color(0xFFCEC7D8),
                    height: 1.45,
                  ),
                ),
                if (item.uncertaintyReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.uncertaintyReason!,
                    style: const TextStyle(color: AppTheme.amber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.title,
    required this.icon,
    required this.notes,
    this.urgent = false,
  });
  final String title;
  final IconData icon;
  final List<EvidenceNote> notes;
  final bool urgent;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: urgent ? const Color(0xFFF87171) : AppTheme.lavender,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...notes.map(
            (e) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(
                e.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(e.subtitle),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF100D19),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'From your document: “${e.evidence}”',
                    style: const TextStyle(color: Color(0xFFB9B1C8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ReminderSetupView extends StatefulWidget {
  const ReminderSetupView({super.key});
  @override
  State<ReminderSetupView> createState() => _ReminderSetupViewState();
}

class _ReminderSetupViewState extends State<ReminderSetupView> {
  final enabled = <String, bool>{};
  bool previewing = false;
  @override
  Widget build(BuildContext context) {
    final plan = context.watch<CarePlanCubit>().state.plan!;
    final candidates = plan.items.where((e) => e.reminderEligible).toList();
    for (final item in candidates) {
      enabled.putIfAbsent(item.id, () => true);
    }
    return PageShell(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: context.read<CarePlanCubit>().showPlan,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to plan',
              ),
              const Expanded(child: Brand()),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Private reminders',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Only confirmed, time-specific instructions are eligible. Suggested times are yours to review before enabling.',
            style: TextStyle(color: Color(0xFFB9B1C8)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF18221F),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF6EE7B7)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lock-screen text hides patient, medicine, and diagnosis details.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...candidates.map(
            (item) => Card(
              child: SwitchListTile(
                value: enabled[item.id]!,
                onChanged: (v) => setState(() => enabled[item.id] = v),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_timingName(item.timing)} • ${_suggestedTime(item.timing)}\nCarePath reminder: Check your recovery plan for the scheduled instruction.',
                ),
                secondary: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.lavender,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Demo: reminders approved. Notification permission would be requested now on device.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notifications_rounded),
            label: const Text('Enable selected reminders'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: previewing
                ? null
                : () {
                    setState(() => previewing = true);
                    Timer(const Duration(seconds: 10), () {
                      if (!mounted) return;
                      setState(() => previewing = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'CarePath reminder: Check your recovery plan for the scheduled instruction.',
                          ),
                        ),
                      );
                    });
                  },
            icon: const Icon(Icons.timer_outlined),
            label: Text(
              previewing
                  ? 'Preview arrives in 10 seconds…'
                  : 'Demo preview in 10 seconds',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Demo preview uses synthetic data and does not change the medical schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF81798E)),
          ),
        ],
      ),
    );
  }
}

IconData _timingIcon(PlanTiming timing) => switch (timing) {
  PlanTiming.morning => Icons.wb_sunny_outlined,
  PlanTiming.afternoon => Icons.light_mode_outlined,
  PlanTiming.evening => Icons.nights_stay_outlined,
  PlanTiming.bedtime => Icons.bedtime_outlined,
  PlanTiming.anytime => Icons.schedule,
};
String _timingName(PlanTiming timing) => switch (timing) {
  PlanTiming.morning => 'Morning',
  PlanTiming.afternoon => 'Afternoon',
  PlanTiming.evening => 'Evening',
  PlanTiming.bedtime => 'Bedtime',
  PlanTiming.anytime => 'Anytime',
};
String _suggestedTime(PlanTiming timing) => switch (timing) {
  PlanTiming.morning => '8:00 AM',
  PlanTiming.afternoon => '1:00 PM',
  PlanTiming.evening => '6:00 PM',
  PlanTiming.bedtime => '9:00 PM',
  PlanTiming.anytime => 'Not scheduled',
};

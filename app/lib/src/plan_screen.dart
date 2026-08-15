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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Brand()),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          side: const BorderSide(color: Color(0xFF38295E)),
                        ),
                        onPressed: context.read<CarePlanCubit>().startNewUpload,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text(
                          'Upload New',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${plan.patientName}’s Recovery Plan',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.hospital} • 7-day schedule',
                    style: const TextStyle(
                      color: Color(0xFF9C93AC),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CollapsibleOverview(overview: plan.overview),
                  if (plan.issues.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CollapsibleConfirmationPanel(issues: plan.issues),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayHeader(
              plan: plan,
              selected: state.selectedDay,
              onSelected: context.read<CarePlanCubit>().selectDay,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            sliver: SliverList.list(
              children: [
                _DayTimeline(plan: plan, day: state.selectedDay),
                const SizedBox(height: 28),
                _EvidenceSection(
                  title: 'Follow-ups & tests',
                  icon: Icons.calendar_month_outlined,
                  notes: plan.followUps,
                ),
                const SizedBox(height: 14),
                _EvidenceSection(
                  title: 'Warning signs from your document',
                  icon: Icons.warning_amber_rounded,
                  notes: plan.warnings,
                  urgent: true,
                ),
                if (plan.extractionWarnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              plan.extractionWarnings.join('\n'),
                              style: const TextStyle(
                                color: Color(0xFFD7C9A1),
                                fontSize: 13,
                              ),
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

class _CollapsibleOverview extends StatelessWidget {
  const _CollapsibleOverview({required this.overview});
  final String overview;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1E1733),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF38295E)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E1F52),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppTheme.lavender,
              size: 20,
            ),
          ),
          title: const Text(
            'Doctor’s Discharge Summary',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: const Text(
            'Tap to view clinical overview',
            style: TextStyle(color: Color(0xFF9C93AC), fontSize: 12),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF130E22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                overview,
                style: const TextStyle(
                  height: 1.5,
                  fontSize: 13.5,
                  color: Color(0xFFE2DCED),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleConfirmationPanel extends StatelessWidget {
  const _CollapsibleConfirmationPanel({required this.issues});
  final List<ConfirmationIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF2B2213),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF655020)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF453416),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: AppTheme.amber,
              size: 20,
            ),
          ),
          title: Text(
            '${issues.length} item${issues.length > 1 ? "s" : ""} to confirm',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFFFFE6A5),
            ),
          ),
          subtitle: const Text(
            'Questions to ask doctor before taking medicines',
            style: TextStyle(color: Color(0xFFD7C9A1), fontSize: 12),
          ),
          children: [
            ...issues.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D170B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF453416)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            e.important ? Icons.priority_high : Icons.edit_note,
                            color: AppTheme.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFFFFE6A5),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: e.important
                                  ? const Color(0xFF5A1E1E)
                                  : const Color(0xFF382D16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e.important ? 'Important' : 'Advisory',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: e.important
                                    ? const Color(0xFFFF8B8B)
                                    : const Color(0xFFFFE6A5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ask: ${e.question}',
                        style: const TextStyle(
                          color: Color(0xFFE8D9B2),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends SliverPersistentHeaderDelegate {
  _DayHeader({
    required this.plan,
    required this.selected,
    required this.onSelected,
  });

  final DischargePlan plan;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

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
        final isSelected = day == selected;
        final label = plan.dayChipLabel(day);
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onSelected(day),
          selectedColor: const Color(0xFF4A3482),
          backgroundColor: const Color(0xFF1E1733),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppTheme.lavender : const Color(0xFF38295E),
            ),
          ),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFFB9B1C8),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemCount: 7,
    ),
  );

  @override
  bool shouldRebuild(covariant _DayHeader old) =>
      old.selected != selected || old.plan != plan;
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
          plan.dayFullHeading(day),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '${items.length} item${items.length == 1 ? "" : "s"} scheduled for today. Tap any card for source evidence.',
          style: const TextStyle(color: Color(0xFF9C93AC), fontSize: 13),
        ),
        const SizedBox(height: 18),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF181329),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF282040)),
            ),
            child: const Center(
              child: Text(
                'No scheduled instructions for this day.',
                style: TextStyle(color: Color(0xFF9C93AC)),
              ),
            ),
          )
        else
          ...PlanTiming.values.map((timing) {
            final timed = items.where((e) => e.timing == timing).toList();
            if (timed.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CollapsibleTimingGroup(timing: timing, items: timed),
            );
          }),
      ],
    );
  }
}

class _CollapsibleTimingGroup extends StatefulWidget {
  const _CollapsibleTimingGroup({required this.timing, required this.items});

  final PlanTiming timing;
  final List<PlanItem> items;

  @override
  State<_CollapsibleTimingGroup> createState() =>
      _CollapsibleTimingGroupState();
}

class _CollapsibleTimingGroupState extends State<_CollapsibleTimingGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF19132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C1E4E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1C52),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _timingIcon(widget.timing),
                      size: 16,
                      color: AppTheme.lavender,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _timingName(widget.timing).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.lavender,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${_suggestedTime(widget.timing)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9C93AC),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1E4E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF9C93AC),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF2C1E4E)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PlanItemCard(item: item),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
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
      elevation: 0,
      color: const Color(0xFF130E22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: uncertain ? const Color(0xFF5A4418) : const Color(0xFF281E40),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: uncertain
                  ? const Color(0xFF3A2C14)
                  : const Color(0xFF282040),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              uncertain ? Icons.help_outline : Icons.check_rounded,
              color: uncertain ? AppTheme.amber : AppTheme.lavender,
              size: 20,
            ),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.instruction,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
                if (item.detail?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221A38),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.detail!,
                        style: const TextStyle(
                          color: Color(0xFFB4ACCE),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (uncertain)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'NEEDS CONFIRMATION',
                      style: TextStyle(
                        color: AppTheme.amber,
                        fontSize: 10.5,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0916),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF241A3B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FROM YOUR SOURCE DOCUMENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppTheme.lavender,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    '“${item.evidence}”',
                    style: const TextStyle(
                      color: Color(0xFFCEC7D8),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  if (item.uncertaintyReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.uncertaintyReason!,
                      style: const TextStyle(
                        color: AppTheme.amber,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () =>
                            showMedicationReminderAlert(context, item),
                        icon: const Icon(Icons.alarm_on_rounded, size: 16),
                        label: const Text(
                          'Test In-App Reminder',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: const Color(0xFF19132B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: urgent ? const Color(0xFF4E2020) : const Color(0xFF2C1E4E),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: urgent ? const Color(0xFF381515) : const Color(0xFF2A1C52),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: urgent ? const Color(0xFFF87171) : AppTheme.lavender,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: urgent ? const Color(0xFFFFB4B4) : Colors.white,
            ),
          ),
          subtitle: Text(
            '${notes.length} item${notes.length == 1 ? "" : "s"} • Tap to view',
            style: const TextStyle(color: Color(0xFF9C93AC), fontSize: 12),
          ),
          children: [
            ...notes.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF100D19),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF22173B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF9C93AC),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'From document: “${e.evidence}”',
                        style: const TextStyle(
                          color: Color(0xFFB9B1C8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            'Medication reminders',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Scheduled reminders based on your doctor’s discharge instructions.',
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
                    'Lock-screen text hides sensitive medical details for your privacy.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...candidates.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: enabled[item.id]!,
                      onChanged: (v) => setState(() => enabled[item.id] = v),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${_timingName(item.timing)} • ${_suggestedTime(item.timing)}\n${item.instruction}',
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B1D4C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.medication_rounded,
                          color: AppTheme.lavender,
                          size: 22,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                            onPressed: () =>
                                showMedicationReminderAlert(context, item),
                            icon: const Icon(Icons.alarm_on_rounded, size: 16),
                            label: const Text(
                              'Test In-App Alert',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    'Reminders enabled for all selected medications.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notifications_rounded),
            label: const Text('Save & enable selected reminders'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: (previewing || candidates.isEmpty)
                ? null
                : () {
                    setState(() => previewing = true);
                    Timer(const Duration(seconds: 10), () {
                      if (!mounted) return;
                      setState(() => previewing = false);
                      showMedicationReminderAlert(context, candidates.first);
                    });
                  },
            icon: const Icon(Icons.timer_outlined),
            label: Text(
              previewing
                  ? 'Simulating reminder in 10 seconds…'
                  : 'Simulate reminder alert (10s)',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Reminders are based on source evidence from your hospital summary.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF81798E)),
          ),
        ],
      ),
    );
  }
}

void showMedicationReminderAlert(BuildContext context, PlanItem item) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: const Color(0xFF1B152B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFF4A3482), width: 1.5),
      ),
      contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33205A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.lavender.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: AppTheme.lavender,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEDICATION REMINDER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: AppTheme.lavender,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_timingName(item.timing)} • ${_suggestedTime(item.timing)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCEC7D8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF9C93AC),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF130E22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2E224E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.medication_rounded,
                        color: AppTheme.lavender,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.instruction,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE2DCED),
                      height: 1.45,
                    ),
                  ),
                  if (item.detail != null && item.detail!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF241A3E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.detail!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB4ACCE),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0916),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Source: “${item.evidence}”',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF8E86A2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF45366E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.snooze_rounded,
                                color: AppTheme.lavender,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Snoozed ${item.title} for 10 minutes.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.snooze_rounded, size: 16),
                    label: const Text('Snooze'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF103322),
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Taken: ${item.title} recorded.',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'Mark as Taken',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
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
  PlanTiming.anytime => 'As needed',
};

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_cubit.dart';
import 'storage_service.dart';
import 'theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarePlanCubit>().state;
    final summaries = state.savedSummaries;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: summaries.isEmpty
              ? _EmptyHistoryView(
                  onUpload: () {
                    context.read<CarePlanCubit>().startNewUpload();
                  },
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1B4B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder_shared_outlined,
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
                                'Manage Summaries',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${summaries.length} saved discharge record${summaries.length == 1 ? "" : "s"}',
                                style: const TextStyle(
                                  color: Color(0xFF9C93AC),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ...summaries.map(
                      (summary) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _SummaryCard(
                          summary: summary,
                          isActive: summary.id == state.activeSummaryId,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.isActive});

  final SavedSummary summary;
  final bool isActive;

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1B152B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            SizedBox(width: 10),
            Text('Delete Summary?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the discharge record for ${summary.patientName} (${summary.hospital})?',
          style: const TextStyle(color: Color(0xFFCEC7D8), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC4B5FD),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<CarePlanCubit>().deleteSummary(summary.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isActive ? const Color(0xFF1F1836) : const Color(0xFF161224),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? AppTheme.lavender : const Color(0xFF2C2248),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                        summary.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary.hospital,
                        style: const TextStyle(
                          color: Color(0xFFB4ACCE),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF103322),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF238453)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'ACTIVE PLAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (summary.dischargeDate != null &&
                    summary.dischargeDate!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF241A3E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: AppTheme.lavender,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Discharge: ${summary.dischargeDate}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFCEC7D8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF241A3E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.medication_outlined,
                        size: 13,
                        color: AppTheme.lavender,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${summary.medicationCount} medicines',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFCEC7D8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF281E40)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isActive) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      foregroundColor: AppTheme.lavender,
                      side: const BorderSide(
                        color: Color(0xFF5B458E),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      context.read<CarePlanCubit>().setActiveSummary(
                        summary.id,
                      );
                    },
                    icon: const Icon(
                      Icons.radio_button_checked_rounded,
                      size: 16,
                      color: AppTheme.lavender,
                    ),
                    label: const Text(
                      'Set as Active',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: isActive
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF382364),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    context.read<CarePlanCubit>().setActiveSummary(summary.id);
                  },
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'View Plan',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE57373),
                    size: 20,
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView({required this.onUpload});
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF22183C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF3B2A64)),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 34,
              color: AppTheme.lavender,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'No saved summaries yet',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload and confirm your hospital discharge summary to manage it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9C93AC), height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload discharge summary'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../models/assignment.dart';
import 'assignment_detail_screen.dart';

class AssignmentsListScreen extends StatefulWidget {
  const AssignmentsListScreen({super.key});

  @override
  State<AssignmentsListScreen> createState() => _AssignmentsListScreenState();
}

class _AssignmentsListScreenState extends State<AssignmentsListScreen> {
  int _filterIndex = 0; // 0 = pending, 1 = done, 2 = all
  static const teal = Color(0xFF1AB8B8);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUser?.uid ?? '';

    List<Assignment> filtered;
    if (_filterIndex == 0) {
      filtered = provider.pendingAssignments;
    } else if (_filterIndex == 1) {
      filtered = provider.doneAssignments;
    } else {
      filtered = provider.assignments;
    }

    // Sort by due date ascending
    filtered = [...filtered]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'Pending',
                selected: _filterIndex == 0,
                onTap: () => setState(() => _filterIndex = 0),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Done',
                selected: _filterIndex == 1,
                onTap: () => setState(() => _filterIndex = 1),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'All',
                selected: _filterIndex == 2,
                onTap: () => setState(() => _filterIndex = 2),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No assignments here',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final a = filtered[index];
                    return _AssignmentListTile(
                      assignment: a,
                      currentUserId: uid,
                      partnerName: provider.partner?.displayName ?? 'Partner',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AssignmentDetailScreen(assignmentId: a.assignmentId),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const teal = Color(0xFF1AB8B8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? teal : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AssignmentListTile extends StatelessWidget {
  final Assignment assignment;
  final String currentUserId;
  final String partnerName;
  final VoidCallback onTap;

  const _AssignmentListTile({
    required this.assignment,
    required this.currentUserId,
    required this.partnerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final myDone = assignment.isDone(currentUserId);
    final partnerEntry = assignment.statusByUser.entries
        .firstWhere((e) => e.key != currentUserId,
            orElse: () => const MapEntry('', 'pending'));
    final partnerDone = partnerEntry.value == 'done';
    final isOverdue = assignment.isOverdue && !myDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        assignment.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Overdue',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${assignment.dueDate.day}/${assignment.dueDate.month}/${assignment.dueDate.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      myDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: myDone ? Colors.green : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text('You',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    Icon(
                      partnerDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: partnerDone ? Colors.green : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(partnerName,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
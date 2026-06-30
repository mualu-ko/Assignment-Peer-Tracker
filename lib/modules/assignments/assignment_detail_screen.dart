import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_provider.dart';
import '../../models/assignment.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentDetailScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final _linkController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSendingFeedback = false;
  String? _error;

  static const teal = Color(0xFF1AB8B8);

  @override
  void dispose() {
    _linkController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String input) {
    String urlToTest = input.trim();
    if (!urlToTest.startsWith('http://') &&
        !urlToTest.startsWith('https://')) {
      urlToTest = 'https://$urlToTest';
    }
    final uri = Uri.tryParse(urlToTest);
    return uri != null && uri.hasAuthority && uri.host.contains('.');
  }

  String _normalizeUrl(String input) {
    String url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  Future<void> _submitLink(Assignment assignment) async {
    final input = _linkController.text.trim();
    if (input.isEmpty || !_isValidUrl(input)) {
      setState(() => _error = 'Please enter a valid link');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await context
          .read<AppProvider>()
          .submitLink(assignment.assignmentId, _normalizeUrl(input));
      _linkController.clear();
    } catch (e) {
      setState(() => _error = 'Failed to submit. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markDone(Assignment assignment) async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<AppProvider>().markDone(assignment.assignmentId);
    } catch (e) {
      setState(() => _error = 'Failed to update. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendFeedback(Assignment assignment) async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingFeedback = true);
    try {
      await context
          .read<AppProvider>()
          .submitFeedback(assignment.assignmentId, text);
      _feedbackController.clear();
    } catch (e) {
      setState(() => _error = 'Failed to send feedback.');
    } finally {
      if (mounted) setState(() => _isSendingFeedback = false);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link')),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final assignment = provider.assignments.firstWhere(
      (a) => a.assignmentId == widget.assignmentId,
      orElse: () => provider.assignments.first,
    );

    final uid = provider.currentUser?.uid ?? '';
    final partner = provider.partner;
    final partnerId = partner?.uid ?? '';

    final myDone = assignment.isDone(uid);
    final myLink = assignment.getLink(uid);
    final partnerDone = assignment.isDone(partnerId);
    final partnerLink = assignment.getLink(partnerId);
    final partnerFeedback = assignment.getFeedback(partnerId);
    final myFeedback = assignment.getFeedback(uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(assignment.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assignment.description.isNotEmpty) ...[
              Text(
                assignment.description,
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Due ${assignment.dueDate.day}/${assignment.dueDate.month}/${assignment.dueDate.year}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // MY STATUS
            const Text('Your submission',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),

            if (myDone && myLink != null && myLink.isNotEmpty)
              _SubmittedCard(link: myLink, onOpen: () => _openLink(myLink))
            else if (myDone)
              _StatusBanner(
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  text: 'Marked as done')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _linkController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'drive.google.com/...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: _isSubmitting ? null : () => _submitLink(assignment),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => _markDone(assignment),
                    child: const Text('No link — just mark as done'),
                  ),
                ],
              ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
            ],

            const SizedBox(height: 28),

            // PARTNER STATUS
            Text("${partner?.displayName ?? 'Partner'}'s submission",
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),

            if (partnerDone && partnerLink != null && partnerLink.isNotEmpty)
              _SubmittedCard(
                  link: partnerLink, onOpen: () => _openLink(partnerLink))
            else if (partnerDone)
              _StatusBanner(
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  text: 'Marked as done')
            else
              Row(
                children: [
                  _StatusBanner(
                    icon: Icons.hourglass_empty_rounded,
                    color: Colors.orange,
                    text: 'Still pending',
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nudge sent! (local notification demo)'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 16),
                    label: const Text('Nudge'),
                    style: OutlinedButton.styleFrom(foregroundColor: teal),
                  ),
                ],
              ),

            const SizedBox(height: 28),

            // FEEDBACK
            const Text('Feedback',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),

            if (partnerFeedback != null && partnerFeedback.isNotEmpty)
              _FeedbackBubble(
                label: partner?.displayName ?? 'Partner',
                text: partnerFeedback,
                isMine: false,
              ),

            if (myFeedback != null && myFeedback.isNotEmpty)
              _FeedbackBubble(
                label: 'You',
                text: myFeedback,
                isMine: true,
              ),

            TextField(
              controller: _feedbackController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Leave feedback for your partner...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _isSendingFeedback
                      ? null
                      : () => _sendFeedback(assignment),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmittedCard extends StatelessWidget {
  final String link;
  final VoidCallback onOpen;

  const _SubmittedCard({required this.link, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.withOpacity(0.15)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              link,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(onPressed: onOpen, child: const Text('Open')),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

class _FeedbackBubble extends StatelessWidget {
  final String label;
  final String text;
  final bool isMine;

  const _FeedbackBubble({
    required this.label,
    required this.text,
    required this.isMine,
  });

  static const teal = Color(0xFF1AB8B8);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMine
            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
            : teal.withOpacity(isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMine
                  ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                  : teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

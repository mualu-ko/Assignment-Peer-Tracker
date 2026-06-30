class Assignment {
  final String assignmentId;
  final String pairId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String createdBy;
  final int version;
  final Map<String, String> statusByUser;
  final Map<String, String> linkByUser;
  final Map<String, String> feedbackByUser;

  Assignment({
    required this.assignmentId,
    required this.pairId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdBy,
    required this.version,
    required this.statusByUser,
    required this.linkByUser,
    required this.feedbackByUser,
  });

  bool isDone(String uid) => statusByUser[uid] == 'done';
  String? getLink(String uid) => linkByUser[uid];
  String? getFeedback(String uid) => feedbackByUser[uid];

  bool get bothDone => statusByUser.values.every((s) => s == 'done');
  bool get isOverdue => dueDate.isBefore(DateTime.now());

  factory Assignment.fromFirestore(Map<String, dynamic> data, String id) {
    return Assignment(
      assignmentId: id,
      pairId: data['pairId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: DateTime.parse(data['dueDate']),
      createdBy: data['createdBy'] ?? '',
      version: data['version'] ?? 1,
      statusByUser: Map<String, String>.from(data['statusByUser'] ?? {}),
      linkByUser: Map<String, String>.from(data['linkByUser'] ?? {}),
      feedbackByUser: Map<String, String>.from(data['feedbackByUser'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pairId': pairId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'createdBy': createdBy,
      'version': version,
      'statusByUser': statusByUser,
      'linkByUser': linkByUser,
      'feedbackByUser': feedbackByUser,
    };
  }
}
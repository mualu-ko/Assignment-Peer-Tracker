import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  AppUser? _currentUser;
  AppUser? _partner;
  List<Assignment> _assignments = [];
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  AppUser? get partner => _partner;
  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isPaired => _currentUser?.isPaired ?? false;

  // Filtered assignment lists
  List<Assignment> get pendingAssignments => _assignments
      .where((a) => !a.isDone(_currentUser?.uid ?? ''))
      .toList();

  List<Assignment> get doneAssignments => _assignments
      .where((a) => a.isDone(_currentUser?.uid ?? ''))
      .toList();

  List<Assignment> get dueSoonAssignments => _assignments.where((a) {
        final diff = a.dueDate.difference(DateTime.now()).inHours;
        return diff <= 48 && diff >= 0 && !a.isDone(_currentUser?.uid ?? '');
      }).toList();

  // ── Auth ──────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _currentUser = user;
        await _loadPartnerAndAssignments();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCurrentUser() async {
    _setLoading(true);
    try {
      final user = await _authService.getCurrentAppUser();
      if (user != null) {
        _currentUser = user;

        // Self-heal: check if a pair exists even if pairId wasn't saved
        if (_currentUser!.pairId == null) {
          final existingPairId =
              await _firestoreService.findExistingPairForUser(_currentUser!.uid);
          if (existingPairId != null) {
            await _firestoreService.updateUserProfile(
                _currentUser!.uid, {'pairId': existingPairId});
            _currentUser = _currentUser!.copyWith(pairId: existingPairId);
          }
        }

        await _loadPartnerAndAssignments();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _partner = null;
    _assignments = [];
    notifyListeners();
  }

  // ── Pairing ───────────────────────────────────────

  Future<String> createPairCode() async {
    final code = await _firestoreService.createPairCode(_currentUser!.uid);

    _firestoreService.watchInviteConsumed(code).listen((pairId) async {
      if (pairId != null && _currentUser?.pairId == null) {
        await _firestoreService.updateUserProfile(
            _currentUser!.uid, {'pairId': pairId});
        _currentUser = _currentUser!.copyWith(pairId: pairId);
        await _firestoreService.deleteInvite(code); // cleanup
        await _loadPartnerAndAssignments();
        notifyListeners();
      }
    });

    return code;
  }

  Future<bool> joinWithCode(String code) async {
    _setLoading(true);
    try {
      final pairId =
          await _firestoreService.joinWithCode(code, _currentUser!.uid);
      if (pairId != null) {
        _currentUser = _currentUser!.copyWith(pairId: pairId);
        await _loadPartnerAndAssignments();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Profile ───────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    await _firestoreService.updateUserProfile(
        _currentUser!.uid, {'displayName': name});
    _currentUser = _currentUser!.copyWith(displayName: name);
    notifyListeners();
  }

  Future<void> updateAvatar(String avatar) async {
    await _firestoreService.updateUserProfile(
        _currentUser!.uid, {'avatar': avatar});
    _currentUser = _currentUser!.copyWith(avatar: avatar);
    notifyListeners();
  }

  // ── Assignments ───────────────────────────────────

  Future<void> createAssignment(Assignment assignment) async {
    await _firestoreService.createAssignment(assignment);
  }

  Future<void> submitLink(String assignmentId, String link) async {
    _optimisticUpdate(assignmentId, status: 'done', link: link);
    await _firestoreService.updateAssignmentField(assignmentId, {
      'linkByUser.${_currentUser!.uid}': link,
      'statusByUser.${_currentUser!.uid}': 'done',
    });
  }

  Future<void> markDone(String assignmentId) async {
    _optimisticUpdate(assignmentId, status: 'done');
    await _firestoreService.updateAssignmentField(assignmentId, {
      'statusByUser.${_currentUser!.uid}': 'done',
    });
  }

  void _optimisticUpdate(String assignmentId, {String? status, String? link}) {
    final index =
        _assignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (index == -1 || _currentUser == null) return;

    final old = _assignments[index];
    final newStatusMap = Map<String, String>.from(old.statusByUser);
    final newLinkMap = Map<String, String>.from(old.linkByUser);

    if (status != null) newStatusMap[_currentUser!.uid] = status;
    if (link != null) newLinkMap[_currentUser!.uid] = link;

    _assignments[index] = Assignment(
      assignmentId: old.assignmentId,
      pairId: old.pairId,
      title: old.title,
      description: old.description,
      dueDate: old.dueDate,
      createdBy: old.createdBy,
      version: old.version,
      statusByUser: newStatusMap,
      linkByUser: newLinkMap,
      feedbackByUser: old.feedbackByUser,
    );

    notifyListeners();
  }
  Future<void> submitFeedback(String assignmentId, String feedback) async {
    _optimisticFeedbackUpdate(assignmentId, feedback);
    await _firestoreService.updateAssignmentField(assignmentId, {
      'feedbackByUser.${_currentUser!.uid}': feedback,
    });
  }

  void _optimisticFeedbackUpdate(String assignmentId, String feedback) {
    final index =
        _assignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (index == -1 || _currentUser == null) return;

    final old = _assignments[index];
    final newFeedbackMap = Map<String, String>.from(old.feedbackByUser);
    newFeedbackMap[_currentUser!.uid] = feedback;

    _assignments[index] = Assignment(
      assignmentId: old.assignmentId,
      pairId: old.pairId,
      title: old.title,
      description: old.description,
      dueDate: old.dueDate,
      createdBy: old.createdBy,
      version: old.version,
      statusByUser: old.statusByUser,
      linkByUser: old.linkByUser,
      feedbackByUser: newFeedbackMap,
    );

    notifyListeners();
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _firestoreService.deleteAssignment(assignmentId);
  }

  // ── Internal ──────────────────────────────────────

 Future<void> _loadPartnerAndAssignments() async {
   if (_currentUser?.pairId == null) return;

   _firestoreService
       .streamAssignments(_currentUser!.pairId!)
       .listen((assignments) {
     _assignments = assignments;
     notifyListeners();
   });

   final members =
       await _firestoreService.getPairMembers(_currentUser!.pairId!);
   if (members.isNotEmpty) {
     final partnerId =
         members.firstWhere((id) => id != _currentUser!.uid);
     _partner = await _firestoreService.getUser(partnerId);
     notifyListeners();
   }
 }
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
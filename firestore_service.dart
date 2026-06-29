import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/timetable_model.dart';
import '../models/announcement_model.dart';
import '../models/resource_model.dart';
import '../models/class_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── USER ────────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return UserModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
    }
    return null;
  }

  // ─── CLASSES ─────────────────────────────────────────────────────────────

  Stream<List<ClassModel>> getClasses() {
    return _db
        .collection('classes')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClassModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get classes where student is enrolled
  Stream<List<ClassModel>> getClassesForStudent(String uid) {
    return _db
        .collection('classes')
        .where('studentIds', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClassModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get classes created by a lecturer
  Stream<List<ClassModel>> getClassesForLecturer(String uid) {
    return _db
        .collection('classes')
        .where('createdBy', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClassModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addClass(ClassModel item) async {
    await _db.collection('classes').add(item.toMap());
  }

  Future<void> updateClass(ClassModel item) async {
    await _db.collection('classes').doc(item.id).update(item.toMap());
  }

  Future<void> deleteClass(String id) async {
    await _db.collection('classes').doc(id).delete();
  }

  // Add student to class by uid
  Future<void> addStudentToClass(String classId, String studentUid) async {
    await _db.collection('classes').doc(classId).update({
      'studentIds': FieldValue.arrayUnion([studentUid]),
    });
  }

  // Remove student from class
  Future<void> removeStudentFromClass(
      String classId, String studentUid) async {
    await _db.collection('classes').doc(classId).update({
      'studentIds': FieldValue.arrayRemove([studentUid]),
    });
  }

  // ─── TIMETABLE ───────────────────────────────────────────────────────────

  // For lecturer/admin — get timetable for a specific class
  Stream<List<TimetableModel>> getTimetableForClass(String classId) {
    return _db
        .collection('timetable')
        .where('classId', isEqualTo: classId)
        .orderBy('day')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TimetableModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // For student — get timetable for all their classes
  Stream<List<TimetableModel>> getTimetableForStudent(
      List<String> classIds) {
    if (classIds.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('timetable')
        .where('classId', whereIn: classIds)
        .orderBy('day')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TimetableModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addTimetable(TimetableModel item) async {
    await _db.collection('timetable').add(item.toMap());
  }

  Future<void> updateTimetable(TimetableModel item) async {
    await _db.collection('timetable').doc(item.id).update(item.toMap());
  }

  Future<void> deleteTimetable(String id) async {
    await _db.collection('timetable').doc(id).delete();
  }

  // ─── ANNOUNCEMENTS ───────────────────────────────────────────────────────

  // For student — get general + their class announcements
  Stream<List<AnnouncementModel>> getAnnouncementsForStudent(
      List<String> classIds) {
    final ids = ['general', ...classIds];
    return _db
        .collection('announcements')
        .where('classId', whereIn: ids)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AnnouncementModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // For lecturer/admin — get announcements for a specific class + general
  Stream<List<AnnouncementModel>> getAnnouncementsForClass(String classId) {
    final ids = ['general', classId];
    return _db
        .collection('announcements')
        .where('classId', whereIn: ids)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AnnouncementModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addAnnouncement(AnnouncementModel item) async {
    await _db.collection('announcements').add(item.toMap());
  }

  Future<void> updateAnnouncement(AnnouncementModel item) async {
    await _db
        .collection('announcements')
        .doc(item.id)
        .update(item.toMap());
  }

  Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
  }

  // ─── RESOURCES ───────────────────────────────────────────────────────────

  // For student — get resources for their classes
  Stream<List<ResourceModel>> getResourcesForStudent(List<String> classIds) {
    if (classIds.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('resources')
        .where('classId', whereIn: classIds)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ResourceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // For lecturer/admin — get resources for a specific class
  Stream<List<ResourceModel>> getResourcesForClass(String classId) {
    return _db
        .collection('resources')
        .where('classId', isEqualTo: classId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ResourceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addResource(ResourceModel item) async {
    await _db.collection('resources').add(item.toMap());
  }

  Future<void> updateResource(ResourceModel item) async {
    await _db.collection('resources').doc(item.id).update(item.toMap());
  }

  Future<void> deleteResource(String id) async {
    await _db.collection('resources').doc(id).delete();
  }
}
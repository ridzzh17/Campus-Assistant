import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'add_edit_class_screen.dart';
import 'class_detail_screen.dart';

class ClassesScreen extends StatefulWidget {
  final UserModel? currentUser;
  const ClassesScreen({super.key, this.currentUser});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool get _canEdit =>
      widget.currentUser?.role == 'lecturer' ||
      widget.currentUser?.role == 'admin';

  Stream<List<ClassModel>> get _classStream {
    final uid = widget.currentUser?.uid ?? '';
    final role = widget.currentUser?.role ?? '';

    if (role == 'admin') {
      return _firestoreService.getClasses();
    } else if (role == 'lecturer') {
      return _firestoreService.getClassesForLecturer(uid);
    } else {
      return _firestoreService.getClassesForStudent(uid);
    }
  }

  Future<void> _deleteClass(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Class'),
        content: const Text(
            'Are you sure? This will not delete related timetable, announcements or resources.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteClass(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Classes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditClassScreen(
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: StreamBuilder<List<ClassModel>>(
        stream: _classStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final classes = snapshot.data ?? [];

          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_outlined,
                      size: 64, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  Text(
                    _canEdit
                        ? 'No classes yet\nTap + to create one'
                        : 'You are not enrolled in any class yet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final cls = classes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      cls.code.isNotEmpty
                          ? cls.code[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    cls.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code: ${cls.code}',
                          style: const TextStyle(
                              color: AppColors.textLight)),
                      Text('${cls.studentIds.length} student(s)',
                          style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12)),
                    ],
                  ),
                  trailing: _canEdit
                      ? PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddEditClassScreen(
                                    currentUser: widget.currentUser,
                                    existingClass: cls,
                                  ),
                                ),
                              );
                            }
                            if (v == 'delete') _deleteClass(cls.id);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        )
                      : const Icon(Icons.chevron_right,
                          color: AppColors.textLight),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassDetailScreen(
                          classModel: cls,
                          currentUser: widget.currentUser,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
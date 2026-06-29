import 'package:flutter/material.dart';
import '../../models/timetable_model.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'add_edit_timetable_screen.dart';

class TimetableScreen extends StatefulWidget {
  final UserModel? currentUser;
  const TimetableScreen({super.key, this.currentUser});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _dayOrder = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
  ];

  bool get _canEdit =>
      widget.currentUser?.role == 'lecturer' ||
      widget.currentUser?.role == 'admin';

  // Get correct stream based on role
  Stream<List<TimetableModel>> get _timetableStream {
    final role = widget.currentUser?.role ?? '';
    final classIds = widget.currentUser?.classIds ?? [];

    if (role == 'student') {
      return _firestoreService.getTimetableForStudent(classIds);
    } else {
      // Lecturer/admin — show all timetable entries for their classes
      if (classIds.isEmpty) return Stream.value([]);
      return _firestoreService.getTimetableForStudent(classIds);
    }
  }

  Map<String, List<TimetableModel>> _groupByDay(
      List<TimetableModel> items) {
    final Map<String, List<TimetableModel>> grouped = {};
    for (final day in _dayOrder) {
      grouped[day] = items.where((item) => item.day == day).toList();
    }
    return grouped;
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content:
            const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteTimetable(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Timetable',
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
                    builder: (_) => AddEditTimetableScreen(
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
        stream: _firestoreService.getClasses(),
        builder: (context, classSnapshot) {
          final classes = classSnapshot.data ?? [];

          return StreamBuilder<List<TimetableModel>>(
            stream: _timetableStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 64, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      const Text('No timetable entries yet',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 16)),
                      if (_canEdit)
                        const Text('Tap + to add one',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 14)),
                    ],
                  ),
                );
              }

              final grouped = _groupByDay(items);

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _dayOrder.length,
                itemBuilder: (context, index) {
                  final day = _dayOrder[index];
                  final dayItems = grouped[day]!;

                  if (dayItems.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      ...dayItems.map((item) {
                        // Get class name for this timetable entry
                        String className = '';
                        try {
                          className = classes
                              .firstWhere((c) => c.id == item.classId)
                              .name;
                        } catch (_) {
                          className = '';
                        }

                        return _TimetableCard(
                          item: item,
                          className: className,
                          canEdit: _canEdit,
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditTimetableScreen(
                                  currentUser: widget.currentUser,
                                  existingItem: item,
                                ),
                              ),
                            );
                          },
                          onDelete: () => _deleteItem(item.id),
                        );
                      }),
                      const Divider(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Timetable Card ──────────────────────────────────────────────────────────

class _TimetableCard extends StatelessWidget {
  final TimetableModel item;
  final String className;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimetableCard({
    required this.item,
    required this.className,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.class_, color: AppColors.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.module,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
            ),
            if (className.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  className,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(item.lecturer,
                  style:
                      const TextStyle(color: AppColors.textLight)),
            ]),
            Row(children: [
              const Icon(Icons.room,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(item.room,
                  style:
                      const TextStyle(color: AppColors.textLight)),
              const SizedBox(width: 12),
              const Icon(Icons.access_time,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(item.time,
                  style:
                      const TextStyle(color: AppColors.textLight)),
            ]),
          ],
        ),
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
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
            : null,
      ),
    );
  }
}